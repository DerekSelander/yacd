# yacd (Yet Another Code Decrypter)

<p align="center">Decrypts FairPlay (App Store) applications on iOS 13.4.1 and lower, no jb required</p>
<h4 align="center">Use for research purposes only, I didn't publish this for you to sideload Fortnite</h4>

<p align="center">
  <img width="20%" src="https://github.com/DerekSelander/yacd/blob/master/media/img.png" style="width: 200px">
</p>


This application uses [@s1guza](https://twitter.com/s1guza)'s [Psychic Paper](https://siguza.github.io/psychicpaper/) exploit to be able to read other process memory and the iOS filesystem.

Many alternatives already exist ([original?](https://github.com/stefanesser/dumpdecrypted), [Frida version](https://github.com/AloneMonkey/frida-ios-dump), [past favorite](https://github.com/BishopFox/bfdecrypt)). This was written primarily for a case where I want to get a decrypted IPA from my iOS device and Airdrop it to a computer


## Compile 
You'll need Xcode 12 for the xcproject

Change around the Singing identity and build for an iOS 13.4.1 or lower device. If successful, you'll see the list of GUI applications on your iOS device.

## Usage
First, launch a 3rd party application, then decrypt it from the yacd app (the app whose icon contains [GQ's sexiest man of 2020](https://en.wikipedia.org/wiki/Anthony_Fauci)). Have a receiving computer with Airdrop available nearby.

## Credits 

* [@s1guza](https://twitter.com/s1guza)'s already mentioned [Psychic Paper](https://siguza.github.io/psychicpaper/)  
* [@rodionovme](https://twitter.com/rodionovme)'s [liblorgnette](https://github.com/rodionovd/liblorgnette) as a starting point
* [https://github.com/ZipArchive/ZipArchive](https://github.com/ZipArchive/ZipArchive)
* [https://github.com/SVProgressHUD/SVProgressHUD](https://github.com/SVProgressHUD/SVProgressHUD)

If you make derivatives of this, cite your sources