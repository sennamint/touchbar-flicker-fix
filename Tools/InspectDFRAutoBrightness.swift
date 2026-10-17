import Foundation
import ObjectiveC.runtime

private let frameworkPath =
    "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("CoreBrightness.framework did not load")
}

guard var inspectedClass: AnyClass =
    NSClassFromString("CBAutoBrightnessModuleDFR") else
{
    fatalError("CBAutoBrightnessModuleDFR is unavailable")
}

while true
{
    print("Class: \(NSStringFromClass(inspectedClass))")

    var methodCount: UInt32 = 0

    if let methods = class_copyMethodList(inspectedClass, &methodCount)
    {
        defer
        {
            free(methods)
        }

        print("Methods:")

        for index in 0..<Int(methodCount)
        {
            let method = methods[index]
            let name = NSStringFromSelector(method_getName(method))
            let encoding = method_getTypeEncoding(method)
                .map(String.init(cString:)) ?? "?"
            print("  \(name)  \(encoding)")
        }
    }

    var ivarCount: UInt32 = 0

    if let ivars = class_copyIvarList(inspectedClass, &ivarCount)
    {
        defer
        {
            free(ivars)
        }

        print("Instance variables:")

        for index in 0..<Int(ivarCount)
        {
            let ivar = ivars[index]
            let name = ivar_getName(ivar).map(String.init(cString:)) ?? "?"
            let encoding = ivar_getTypeEncoding(ivar)
                .map(String.init(cString:)) ?? "?"
            print("  \(name)  \(encoding)")
        }
    }

    guard let superclass = class_getSuperclass(inspectedClass),
          superclass != NSObject.self else
    {
        break
    }

    inspectedClass = superclass
}
