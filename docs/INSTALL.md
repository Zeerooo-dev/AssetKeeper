# Install or update AssetKeeper

Download only from https://github.com/Zeerooo-dev/AssetKeeper/releases.
SHA256SUMS is included with each release. Keep the entire PC application folder.

## Android

Open the APK and confirm installation in Android. Your browser may ask permission
to install APKs. Production updates keep the same package and signing certificate.
Do not uninstall the production app before updating; uninstalling removes its data
and encryption key. GitHub never supplies a signing key or asks for inventory data.

The production package is `com.zeerooo.assetkeeper`. Older test APKs used
`com.example.assetkeeper` with a development signing key. These are separate apps:
the first production install starts a separate inventory. Keep the old app until
you have handled its records; there is no automatic cross-install data migration.

## Windows (64-bit)

Extract the complete ZIP, then run `AssetKeeper/assetkeeper.exe`. Windows may warn
because the executable does not have a paid Windows code-signing certificate.
Check the repository and release checksum before running it. To update, close the
app and replace its application folder with the newly extracted folder. Keep the
same Windows account and its Credential Manager entries. Never delete local app
data or reset credentials to update.

## Linux (64-bit)

Extract the TAR.GZ and run `AssetKeeper/assetkeeper`. It targets Ubuntu 24.04 or a
compatible newer desktop with GTK 3, libsecret, jsoncpp and a running Secret Service
keyring. Keep the original OS user and keyring. To update, close the app and replace
its application folder. Do not remove the separate application-support data.

The app checks online on launch after setup and when resumed after four hours.
Settings > Check for updates checks immediately. You can dismiss the popup and
continue offline. Downloads open in your browser; installation is user-confirmed.
Never run old and new PC versions against the same inventory at the same time.
