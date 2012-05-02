LuaD Documentation
============================================
The LuaD documentation is generated using [bootDoc](https://github.com/JakobOvrum/bootDoc)
and can be viewed online [here](http://jakobovrum.github.com/LuaD/).

The documentation can be generated with the following command:

    rdmd bootDoc/generate.d .. --extra=index.d

It assumes that the `luad` source package can be found as `../luad`, i.e.
it assumes that this directory is a subdirectory of the main LuaD branch.
The LuaD `.gitignore` has a `/docs` entry for this purpose.
