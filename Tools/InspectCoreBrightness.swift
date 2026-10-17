import Foundation
import ObjectiveC.runtime

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
private let relevantTerms =
    ["ALS", "Ambient", "Backlight", "Brightness", "DisplayContainer"]

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("CoreBrightness.framework did not load")
}

let classCount = objc_getClassList(nil, 0)
var classes = [AnyClass?](repeating: nil, count: Int(classCount))
let loadedCount = classes.withUnsafeMutableBufferPointer
{
    buffer in
    objc_getClassList(
        AutoreleasingUnsafeMutablePointer(buffer.baseAddress),
        classCount
    )
}

for index in 0..<Int(loadedCount)
{
    guard let inspectedClass = classes[index] else
    {
        continue
    }

    let className = NSStringFromClass(inspectedClass)

    guard relevantTerms.contains(where: className.localizedCaseInsensitiveContains) else
    {
        continue
    }

    var methodCount: UInt32 = 0

    guard let methods = class_copyMethodList(inspectedClass, &methodCount) else
    {
        continue
    }

    defer
    {
        free(methods)
    }

    let relevantMethods = (0..<Int(methodCount)).compactMap
    {
        methodIndex -> String? in
        let method = methods[methodIndex]
        let methodName = NSStringFromSelector(method_getName(method))

        guard relevantTerms.contains(
            where: methodName.localizedCaseInsensitiveContains
        ) || methodName.localizedCaseInsensitiveContains("property") else
        {
            return nil
        }

        let encoding = method_getTypeEncoding(method)
            .map(String.init(cString:)) ?? "?"
        return "  \(methodName)  \(encoding)"
    }

    guard !relevantMethods.isEmpty else
    {
        continue
    }

    print(className)

    for method in relevantMethods.sorted()
    {
        print(method)
    }
}
