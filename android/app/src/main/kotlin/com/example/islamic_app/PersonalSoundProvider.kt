package com.example.zabi

import androidx.core.content.FileProvider

/** A separate component keeps Android from reusing the image-sharing provider. */
class PersonalSoundProvider : FileProvider()
