# TinyTools
Some tools for use with TinyBootstrap.

Currently only 2 tools are provided:
* `TtObjectEncoder`
* `TtInspector`


The `TtInspector` currently allows to display the classes and optionally methods installed in a dynamic image.

## Load TinyTools
To load the TinyTools execute the following (in a regular Pharo 10 image).
```Smalltalk
Metacello new
  repository: 'github://ErikOnBike/TinyTools:main';
  baseline: 'TinyTools';
  load.
```

## `TtObjectEncoder`
The `TtObjectEncoder` which should be executed from a regular Pharo 10 image, allows code (either a Class or a single CompiledMethod) to be exported as an encoded file. This encoded file can be read in by the 'dynamic' tiny image of [TinyBootstrap](https://github.com/ErikOnBike/TinyBootstrap/blob/main/README.md#dynamic-image). This allows executing and installing code into this image dynamically. See some examples below.

To create installable code use one of the following class methods to create or append code to a file:
* `#writeClass:to:` or `#appendClass:to:`
* `writeClass:selectMethods:to: or `#appendClass:selectMethods:to:`
* `writeMethod:to:` or `#appendMethod:to:`

The append methods allow multiple pieces of code to be written to the same file. This allows a sort of code bundle to be created. The order is not important.

### Examples
To create a code file to load the `TtInspector` into the dynamic image, the following code can be executed (in the regular Pharo 10 image).
```Smalltalk
TtObjectEncoder writeClass: TtInspector to: 'inspector.code'.
```

To load the `test1` class method of `TtDynamic` into the dynamic image, the following code can be executed (in the regular Pharo 10 image).
```Smalltalk
TtObjectEncoder writeMethod: (TtDynamic class >> #test1) to: 'test1.code'.
```

Now loading these pieces of code into a dynamic image, perform the followin steps (see also [Dynamic image](https://github.com/ErikOnBike/TinyBootstrap/blob/main/README.md#dynamic-image) creation).
* Create the dynamic image:
  ```bash
  ./tiny-bootstrap.sh -a 64 -s ./dynamic/src -t dynamic.image -c "TtDynamic doIt"
  ```
* Install the inspector into the image and show all installed classes (without saving the image!):
  ```bash
  ./pharo dynamic.image --install inspector.code TtInspector showClasses
  ```
* Install the `test1` method and execute it (without saving the image!):
  ```bash
  ./pharo dynamic.image --install test1.code TtDynamic test1
  ```
* Try to run the test again (without installation, this will fail since image was not saved):
  ```bash
  ./pharo dynamic.image TtDynamic test1
  ```
* Install the `test1` method this time saving the image:
  ```bash
  ./pharo dynamic.image --install test1.code --save
  ```
* If we run the test again it will show the correct response:
  ```bash
  ./pharo dynamic.image TtDynamic test1
  ```
