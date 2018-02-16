# C₂: Corpus Container

Corpus container managed by [CoreData](https://en.wikipedia.org/wiki/Core_Data) for macOS/iOS/tvOS/watchOS to evaluate machine learning with Swift

## Available corpus
 - [MNIST](http://yann.lecun.com/exdb/mnist)
 - [CIFAR10](https://www.cs.toronto.edu/~kriz/)
 - [FashionMNIST](https://github.com/zalandoresearch/fashion-mnist)
 - \[WIP\] [Oxford-IIIT Pet database](http://www.robots.ox.ac.uk/%7Evgg/data/pets/)
 
## Example 1: Build MNIST
no error handling
```swift
//Download and parse the archived data from web and build CoreData persistent store
let container = Container(delegate: nil)
container.build(series: MNIST.train)
```

## Example 2: Use MNIST
no error handling
```swift
let context = container.viewContext

//Fetch 0 indices
let index = try!context.index(series: MNIST.train, labels: ["0"]).first!

//Get a label from the index
let label = index.label //"0"

//Get 0 images
let images = index.contents as! [Image]
//let label = images.first!.index.label//"0"

//Get a 0 image
let image = images.first!
```

## Example 3: Get Float array
no error handling
```swift
let vector: [Float] = image.array
```

## Example 4: Get ciimage and save as png file
no error handling
```swift
let ciimage = image.ciimage
let ciContext = CIContext()
let path = URL(fileURLWithPath: ANY FILEPATH)
try!ciContext.writeTIFFRepresentation(of: ciimage, to: url, format: ciContext.workingFormat, colorSpace: ciContext.workingColorSpace!, options: [:])
```

## Example 5: Get all MNIST train Images
```swift
let indices = try!context.index(series: MNIST.train)
let images = indices.reduce([]) {
  $0 + $1.contents.flatMap{$0 as? Image}
}
```

## Exmaple 6: Get all labels from CIFAR10 and FashionMNIST
```swift
let cifar10_labels = context.label(series: CIFAR10.batch1)
let fashionMNIST_labels = context.label(series: FashionMNIST.train)
```
