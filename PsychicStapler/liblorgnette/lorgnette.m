//
//  lorgnette.c
//  liblorgnette
//
//  Created by Dmitry Rodionov on 9/24/14.
//  Copyright (c) 2014 rodionovd. All rights reserved.
//

#import <Foundation/Foundation.h>

/** We don't want assert() to be stripped out from release builds. */
#ifdef NDEBUG
	#define RD_REENABLE_NDEBUG NDEBUG
	#undef NDEBUG
#endif
#include <assert.h>
#ifdef RD_REENABLE_NDEBUG
	#define NDEBUG RD_REENABLE_NDEBUG
	#undef RD_REENABLE_NDEBUG
#endif
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <libgen.h>
#include <syslog.h>
#include <stdbool.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <mach-o/loader.h>
#include <mach-o/dyld_images.h>
#include <sys/mman.h>


#include "../commons.h"
#include "lorgnette.h"
#include "lorgnette-structs.h"

#define RDFailOnError(function, label) \
	do { \
		if (err != KERN_SUCCESS) { \
			syslog(LOG_NOTICE, "[%d] %s failed with error: %s [%d]\n", \
					__LINE__-1, function, mach_error_string(err), err); \
			goto label; \
		} \
	} while(0)

/** This magic Mach-O header flag implies that image was loaded from dyld shared cache */
#define kImageFromSharedCacheFlag 0x80000000
/** @see _copyin_string() */
#define kRemoteStringBufferSize 2048
/** Default base addresses for 32- and 64-bit executables */
#define ki386DefaultBaseAddress 0x1000
#define kx86_64DefaultBaseAddress 0x100000000

static int _image_headers_in_task(task_t, const char *, mach_vm_address_t*, uint32_t*, uint64_t*, ImageClosure);
static int _image_headers_from_dyld_info64(task_t, task_dyld_info_data_t, const char*, uint32_t*,
										   uint64_t*, uint64_t *, ImageClosure);
static mach_vm_address_t _scan_remote_image_for_symbol(task_t, mach_vm_address_t, const char *, bool *);
static char *_copyin_string(task_t, mach_vm_address_t);

//extern "C" {
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
extern int mremap_encrypted(caddr_t addr, size_t len,
                            uint32_t cryptid, uint32_t cputype,
                            uint32_t cpusubtype);
//};
#pragma mark - Lorgnette

mach_vm_address_t lorgnette_lookup(task_t target, const char *symbol_name)
{
	return lorgnette_lookup_image(target, symbol_name, NULL);
}

mach_vm_address_t lorgnette_lookup_image(task_t target, const char *symbol_name, const char *image_name)
{
	assert(symbol_name);
	assert(strlen(symbol_name) > 0);

	int err = KERN_SUCCESS;
	uint32_t count = 0;
	uint64_t shared_cache_slide = 0x0;
	err = _image_headers_in_task(target, image_name, NULL, &count, &shared_cache_slide, NULL);
	if (err != KERN_SUCCESS) {
		return 0;
	}

	mach_vm_address_t *headers = malloc(sizeof(*headers) * count);
	err =_image_headers_in_task(target, image_name, headers, &count, &shared_cache_slide, NULL);
	if (err != KERN_SUCCESS) {
		free(headers);
		return 0;
	}
	mach_vm_address_t result = 0;
	bool imageFromSharedCache = 0;
	for (uint32_t i = 0; i < count; i++) {
		mach_vm_address_t image = headers[i];
		result = _scan_remote_image_for_symbol(target, image, symbol_name, &imageFromSharedCache);
		if (result > 0) {
			/** Add ASLR slice only for the main image of the target */
			if (i == 0) {
				// FIXME: dirty hardcoding
				/* Get a relative symbol offset */
				if (result < kx86_64DefaultBaseAddress)  {
					result -= ki386DefaultBaseAddress;
				} else {
					result -= kx86_64DefaultBaseAddress;
				}
				/* The header pointer already have ASLR slice included */
				result += headers[0];
			} else if (!imageFromSharedCache) {
				/**
				 * On some setups dyld shared cache doesn't contain some system libraries.
				 * In this case we have to append a base_address+ASLR value to the result.
				 */
				if (headers[i] > kx86_64DefaultBaseAddress && result < kx86_64DefaultBaseAddress) {
					/* x86_64 target */
					result += headers[i];
				}
				if (headers[i] < kx86_64DefaultBaseAddress && result < ki386DefaultBaseAddress) {
					/* i386 target */
					result += headers[i];
				}
			}
			break;
		};
	}
	free(headers);
	/* Add a slide if our target image was a library from the dyld shared cache */
	if (imageFromSharedCache && result > 0) {
		result += shared_cache_slide;
	}

	return result;
}

BOOL enumerate_loaded_modules(task_t target, ImageClosure closure)
{
    int err = KERN_SUCCESS;
    uint32_t count = 0;
    uint64_t shared_cache_slide = 0x0;
    err = _image_headers_in_task(target, NULL, NULL, &count, &shared_cache_slide, closure);
    if (err != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

BOOL enumerate_non_shared_dylib_modules(task_t target, ImageClosure closure)
{
    int err = KERN_SUCCESS;
    ImageClosure wrapperClosure = ^(char* path, mach_vm_address_t start) {
        
        mach_vm_size_t size = sizeof(struct mach_header_64);
        struct mach_header_64 header = {};
        if (mach_vm_read_overwrite(target, start, sizeof(struct mach_header_64), (mach_vm_address_t)&header, &size)) {
            NSLog(@"error");
            return;
        }
        
        if (!(header.flags & MH_DYLIB_IN_CACHE)) {
            closure(path, start);
        }        
    };
    uint32_t count = 0;
    uint64_t shared_cache_slide = 0x0;
    err = _image_headers_in_task(target, NULL, NULL, &count, &shared_cache_slide, wrapperClosure);
    if (err != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

BOOL patch_encrypted_module_with_decrypted_memory(mach_vm_address_t payload, size_t payload_size, mach_vm_address_t file_offset, const char *filePath) {
    
    int fd = open(filePath, O_RDWR);
    if (fd < 0) {
        return NO;
    }
    
//    off_t jj = lseek(fd, 0, SEEK_END);
//    jj = lseek(fd, 0, SEEK_SET);
    
    
//    void * addr = mmap(0, jj, PROT_READ|PROT_EXEC|PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_JIT, fd, 0);
//    void* j = mremap_encrypted(addr + file_offset, payload_size, 0, CPU_TYPE_ARM64, CPU_SUBTYPE_ARM_ALL);
    
    
//    mmap(<#void *#>, <#size_t#>, <#int#>, <#int#>, <#int#>, <#off_t#>)
    
    if (lseek(fd, file_offset, SEEK_SET) < 0) {
        return NO;
    }

    if (write(fd, (const void*)payload, payload_size) != payload_size) {
        return NO;
    }
    
    // Now patch, the LC_ENCRYPTION_64
    if (lseek(fd, 0, SEEK_SET) < 0) {
        return NO;
    }
    
    struct mach_header_64 header;
    read(fd, &header, sizeof(struct mach_header_64));
    if (header.magic != MH_MAGIC_64) {
        return NO;
    }
    
    lseek(fd, 0, SEEK_CUR);
    
    struct load_command load_cmd = {};
    for (int i = 0; i < header.ncmds; i++) {
        
        read(fd, &load_cmd, sizeof(struct load_command));
        lseek(fd, -sizeof(struct load_command), SEEK_CUR); // TODO is pread?

        if (load_cmd.cmd == LC_ENCRYPTION_INFO_64) {
            struct encryption_info_command_64 encryption = {};
            read(fd, &encryption, sizeof(struct encryption_info_command_64));
            lseek(fd, -sizeof(struct encryption_info_command_64), SEEK_CUR); // TODO is pread
            
            lseek(fd, offsetof(struct encryption_info_command_64, cryptid), SEEK_CUR);
            uint32_t zeroed_cryptid = 0;
            if (write(fd, &zeroed_cryptid, sizeof(uint32_t)) != sizeof(uint32_t)) {
                return NO;
            }
            break;
        }
        lseek(fd, load_cmd.cmdsize, SEEK_CUR);
    }
    
    
    close(fd);
    
    return YES;
}

BOOL enumerate_encrypted_modules(task_t target, ImageEncryptionClosure closure)
{
    int err = KERN_SUCCESS;
    ImageClosure wrapperClosure = ^(char* path, mach_vm_address_t module_start) {
        
        mach_vm_size_t size = sizeof(struct mach_header_64);
        struct mach_header_64 header = {};
        if (mach_vm_read_overwrite(target, module_start, sizeof(struct mach_header_64), (mach_vm_address_t)&header, &size)) {
            NSLog(@"error");
            return;
        }
        
        char *payload = calloc(header.sizeofcmds, sizeof(char));
        size = header.sizeofcmds;
        if (mach_vm_read_overwrite(target, module_start + sizeof(struct mach_header_64), header.sizeofcmds, (mach_vm_address_t)payload, &size)) {
            NSLog(@"error");
            return;
        }
        
        uintptr_t pointer = (uintptr_t)payload;
        for (int i = 0; i < header.ncmds; i++) {
            struct load_command *cmd = (struct load_command *)pointer;
            if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64 *encryption_info = (struct encryption_info_command_64*)cmd;
                if (encryption_info->cryptid) {
                    closure(path, module_start, encryption_info->cryptoff, encryption_info->cryptsize);
                }
            }
            pointer += cmd->cmdsize;
        }
        
        free(payload);
        
        
    };
    uint32_t count = 0;
    uint64_t shared_cache_slide = 0x0;
    err = _image_headers_in_task(target, NULL, NULL, &count, &shared_cache_slide, wrapperClosure);
    if (err != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

#pragma mark - All the interesting stuff
/**
 * @abstract
 * Get a list of load addresses of all mach-o images within the target task.
 * @note
 * These addresses could belong to a foreign address space.
 *
 * @param task
 * the target process
 * @param headers (out)
 * the list of length @p count containing addresses of images loaded into the target task
 * @param count (out)
 * the length of @p headers list
 */
static
int _image_headers_in_task(task_t task,
						   const char *suggested_image_name,
						   mach_vm_address_t *headers,
						   uint32_t *count,
						   uint64_t *shared_cache_slide, ImageClosure closure)
{
	task_flavor_t flavor = TASK_DYLD_INFO;
	task_dyld_info_data_t data;
	mach_msg_type_number_t number = TASK_DYLD_INFO_COUNT;
	int err = task_info(task, flavor, (task_info_t)&data, &number);
	RDFailOnError("task_info()", fail);
    return _image_headers_from_dyld_info64(task, data, suggested_image_name, count,
											   headers, shared_cache_slide, closure);
	

fail:
	return KERN_FAILURE;
}

static
int _image_headers_from_dyld_info64(task_t target,
									task_dyld_info_data_t dyld_info,
									const char *suggested_image_name,
									uint32_t *count,
									uint64_t *headers,
									uint64_t *shared_cache_slide,
                                    ImageClosure closure)
{
	assert(count);
	assert(shared_cache_slide);

	int err = KERN_FAILURE;
	struct dyld_all_image_infos_64 infos;
    struct dyld_image_info_64 *array = NULL;
	mach_vm_size_t size = dyld_info.all_image_info_size;
	err = mach_vm_read_overwrite(target, dyld_info.all_image_info_addr, size,
								 (mach_vm_address_t)&infos, &size);
	RDFailOnError("mach_vm_read_overwrite()", fail);

	*count = infos.infoArrayCount;
	*shared_cache_slide = infos.sharedCacheSlide;

	size = sizeof(struct dyld_image_info_64) * (*count);
	array = malloc((size_t)size);
	err = mach_vm_read_overwrite(target, (mach_vm_address_t)infos.infoArray, size,
								 (mach_vm_address_t)array, &size);
	RDFailOnError("mach_vm_read_overwrite()", fail);

	bool should_find_particular_image = (suggested_image_name != NULL);
	if (headers || closure) {
		for (uint32_t i = 0; i < *count; i++) {
			/// FIXME: Find a real location of the first image path
			/* We have to always include the first image in the headers list
			 * because an image filepath's address is slided with an unknown offset,
			 * so we can't read the image name directly. */
            if (closure) {
                char *image_name = _copyin_string(target, array[i].imageFilePath);
                closure(image_name, array[i].imageLoadAddress);
            } else if (!should_find_particular_image || i == 0) {
                headers[i] = (mach_vm_address_t)array[i].imageLoadAddress;
            } else {
				char *image_name = _copyin_string(target, array[i].imageFilePath);
				bool not_found = ({
					strcmp(suggested_image_name, image_name) &&
					strcmp(suggested_image_name, basename(image_name));
				});
				free(image_name);
				if (not_found) {
					headers[i] = 0;
				} else {
					headers[i] = (mach_vm_address_t)array[i].imageLoadAddress;
					break;
				}
			}
		}
	}

	free(array);
	return KERN_SUCCESS;

fail:
	free(array);
	return KERN_FAILURE;
}



/**
 *
 */
static
mach_vm_address_t _scan_remote_image_for_symbol(task_t task,
												mach_vm_address_t remote_header,
												const char *symbol_name,
												bool *imageFromSharedCache)
{
	assert(symbol_name);
	assert(imageFromSharedCache);
	int err = KERN_FAILURE;

	if (remote_header == 0) {
		return 0;
	}

	mach_vm_size_t size = sizeof(struct mach_header);
	struct mach_header header = {0};
	err = mach_vm_read_overwrite(task, remote_header, size, (mach_vm_address_t)&header, &size);
	RDFailOnError("mach_vm_read_overwrite()", fail);

	bool sixtyfourbit = (header.magic == MH_MAGIC_64);
	*imageFromSharedCache = ((header.flags & kImageFromSharedCacheFlag) == kImageFromSharedCacheFlag);

	/* We don't support anything but i386 and x86_64 */
	if (header.magic != MH_MAGIC && header.magic != MH_MAGIC_64) {
		syslog(LOG_NOTICE, "liblorgnette ERROR: found image with unsupported architecture"
				"at %p, skipping it.\n", (void *)remote_header);
		return 0;
	}

	/**
	 * Let's implement some nlist()
	 */
	mach_vm_address_t symtab_addr = 0;
	mach_vm_address_t linkedit_addr = 0;
	mach_vm_address_t text_addr = 0;

	size_t mach_header_size = sizeof(struct mach_header);
	if (sixtyfourbit) {
		mach_header_size = sizeof(struct mach_header_64);
	}
	mach_vm_address_t command_addr = remote_header + mach_header_size;
	struct load_command command = {0};
	size = sizeof(command);

	for (uint32_t i = 0; i < header.ncmds; i++) {
		err = mach_vm_read_overwrite(task, command_addr, size, (mach_vm_address_t)&command, &size);
		RDFailOnError("mach_vm_read_overwrite()", fail);

		if (command.cmd == LC_SYMTAB) {
			symtab_addr = command_addr;
		} else if (command.cmd == LC_SEGMENT || command.cmd == LC_SEGMENT_64) {
			/* struct load_command only has two fields (cmd & cmdsize), while its "child" type
			 * struct segment_command has way more fields including `segname` at index 3, so we just
			 * pretend that we have a real segment_command and skip first two fields away */
			size_t segname_field_offset = sizeof(command);
			mach_vm_address_t segname_addr = command_addr + segname_field_offset;
			char *segname = _copyin_string(task, segname_addr);
			if (0 == strcmp(SEG_TEXT, segname)) {
				text_addr = command_addr;
			} else if (0 == strcmp(SEG_LINKEDIT, segname)) {
				linkedit_addr = command_addr;
			}
			free(segname);
		}
		// go to next load command
		command_addr += command.cmdsize;
	}

	if (!symtab_addr || !linkedit_addr || !text_addr) {
		syslog(LOG_NOTICE, "Invalid Mach-O image header, skipping...\n");
		return 0;
	}

	struct symtab_command symtab = {0};
	size = sizeof(struct symtab_command);
	err = mach_vm_read_overwrite(task, symtab_addr, size, (mach_vm_address_t)&symtab, &size);
	RDFailOnError("mach_vm_read_overwrite", fail);

	// FIXME: find a way to remove the copypasted code below
	// These two snippets share all the logic, but differs in structs and integers
	// they use for reading the data from a target process (32- or 64-bit layout).
	if (sixtyfourbit) {
		struct segment_command_64 linkedit = {0};
		size = sizeof(struct segment_command_64);
		err = mach_vm_read_overwrite(task, linkedit_addr, size,
									 (mach_vm_address_t)&linkedit, &size);
		RDFailOnError("mach_vm_read_overwrite", fail);
		struct segment_command_64 text = {0};
		err = mach_vm_read_overwrite(task, text_addr, size, (mach_vm_address_t)&text, &size);
		RDFailOnError("mach_vm_read_overwrite", fail);

		uint64_t file_slide = linkedit.vmaddr - text.vmaddr - linkedit.fileoff;
		uint64_t strings = remote_header + symtab.stroff + file_slide;
		uint64_t sym_addr = remote_header + symtab.symoff + file_slide;

		for (uint32_t i = 0; i < symtab.nsyms; i++) {
			struct nlist_64 sym = {{0}};
			size = sizeof(struct nlist_64);
			err = mach_vm_read_overwrite(task, sym_addr, size, (mach_vm_address_t)&sym, &size);
			RDFailOnError("mach_vm_read_overwrite", fail);
			sym_addr += size;

			if (!sym.n_value) continue;

			uint64_t symname_addr = strings + sym.n_un.n_strx;
			char *symname = _copyin_string(task, symname_addr);
			/* Ignore the leading "_" character in a symbol name */
			if (0 == strcmp(symbol_name, symname+1)) {
				free(symname);
				return (mach_vm_address_t)sym.n_value;
			}
			free(symname);
		}
	} else {
		struct segment_command linkedit = {0};
		size = sizeof(struct segment_command);
		err = mach_vm_read_overwrite(task, linkedit_addr, size,
									 (mach_vm_address_t)&linkedit, &size);
		RDFailOnError("mach_vm_read_overwrite", fail);
		struct segment_command text = {0};
		err = mach_vm_read_overwrite(task, text_addr, size, (mach_vm_address_t)&text, &size);
		RDFailOnError("mach_vm_read_overwrite", fail);

		uint32_t file_slide = linkedit.vmaddr - text.vmaddr - linkedit.fileoff;
		uint32_t strings = (uint32_t)remote_header + symtab.stroff + file_slide;
		uint32_t sym_addr = (uint32_t)remote_header + symtab.symoff + file_slide;

		for (uint32_t i = 0; i < symtab.nsyms; i++) {
			struct nlist sym = {{0}};
			size = sizeof(struct nlist);
			err = mach_vm_read_overwrite(task, sym_addr, size, (mach_vm_address_t)&sym, &size);
			RDFailOnError("mach_vm_read_overwrite", fail);
			sym_addr += size;

			if (!sym.n_value) continue;

			uint32_t symname_addr = strings + sym.n_un.n_strx;
			char *symname = _copyin_string(task, symname_addr);
			/* Ignore the leading "_" character in a symbol name */
			if (0 == strcmp(symbol_name, symname+1)) {
				free(symname);
				return (mach_vm_address_t)sym.n_value;
			}
			free(symname);
		}
	}

fail:
	return 0;
}

/**
 * @abstract
 * Copy a string from the target task's address space to current address space.
 *
 * @param task
 * The target task.
 * @param pointer
 * The address of a string to copyin.
 *
 * @return
 * A pointer to a string. It may be NULL.
 */
static char *_copyin_string(task_t task, mach_vm_address_t pointer)
{
	assert(pointer > 0);
	int err = KERN_FAILURE;

	/* Since calls to mach_vm_read_overwrite() are expensive we'll just use
	 * a rather big buffer insead of reading char-by-char.
	 */
	// FIXME: what about the size of this buffer?
	// Users can requst symbols with very long names (e.g. C++ mangled method names, etc)
	char buf[kRemoteStringBufferSize] = {0};
	mach_vm_size_t sample_size = sizeof(buf);
	err = mach_vm_read_overwrite(task, pointer, sample_size,
								 (mach_vm_address_t)&buf, &sample_size);
	assert(err == KERN_SUCCESS);
	buf[kRemoteStringBufferSize-1] = '\0';

	char *result = strdup(buf);
	return result;
}
