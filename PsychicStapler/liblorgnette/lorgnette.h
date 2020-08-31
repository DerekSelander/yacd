//
//  lorgnette.h
//  liblorgnette
//
//  Created by Dmitry Rodionov on 9/24/14.
//  Copyright (c) 2014 rodionovd. All rights reserved.
//
#include <mach/mach.h>
#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @abstract
 * Locate a symbol inside an arbitrary process' address space.
 *
 * @note
 * This function iterates local symbols first and only then it looks for symbols
 * in linked libraries.
 *
 * @param target
 * The target process to inspect.
 * @param symbol_name
 * The name of the symbol to find. This parameter must not be NULL.
 *
 * @return
 * An address of the given symbol within the given process, or 0 (zero) if this symbol
 * could not be found.
 *
 * @b Examples
 *
 * Find a @p dlopen symbol address within the current task memory space
 * @code
 * addr = lorgnette_lookup(mach_task_self(), "dlopen");
 * @endcode
 * Find a @p glob_var0 symbol address inside a remote process
 * @code
 * addr = lorgnette_lookup(some_task, "glob_var0");
 * @endcode
 */
mach_vm_address_t lorgnette_lookup(task_t target, const char *symbol_name);

/**
 * @abstract
 * Locate a symbol within a particular image inside an alien process.
 *
 * @param target
 * The target process to inspect.
 * @param symbol_name
 * The name of the symbol to find. This parameter must not be NULL.
 * @param image_name
 * The name of the host image of the given symbol. This may be NULL.
 * The image name should be either a full file path or just a file base name.
 *
 * @return
 * An address of the given symbol within the given process, or 0 (zero) if this symbol
 * could not be found [within the given image, if @p image_name is not NULL].
 *
 * @see lorgnette_lookup()
 */
mach_vm_address_t lorgnette_lookup_image(task_t target, const char *symbol_name, const char *image_name);


// Callback block that returns the relevant dyld_image_info_64 for each modules
typedef void (^ImageClosure)(char* path, mach_vm_address_t module_start);

// Callback block that returns the relevant dyld_image_info_64 for each modules
typedef void (^ImageEncryptionClosure)(char* path, mach_vm_address_t module_start, uint32_t cryptoff, uint32_t cryptsize);

//mach_vm_address_t enumerate_loaded_modules(mach_port_t target, ImageClosure closure);


BOOL enumerate_loaded_modules(task_t target, ImageClosure closure);

BOOL enumerate_non_shared_dylib_modules(task_t target, ImageClosure closure);

BOOL enumerate_encrypted_modules(task_t target, ImageEncryptionClosure closure);

BOOL patch_encrypted_module_with_decrypted_memory(mach_vm_address_t payload, size_t payload_size, mach_vm_address_t file_offset, const char *filePath);
#ifdef __cplusplus
}
#endif
