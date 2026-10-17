import Foundation
import ObjectiveC.runtime

let frameworkPath =
    "/System/Library/PrivateFrameworks/DFRBrightness.framework/DFRBrightness"

guard dlopen(frameworkPath, RTLD_NOW) != nil else
{
    fatalError("DFRBrightness.framework did not load")
}

guard let clientClass: AnyClass = NSClassFromString("DFRBrightnessClient") else
{
    fatalError("DFRBrightnessClient is unavailable")
}

let client = (clientClass as! NSObject.Type).init()
let getDimmingStepSelector = NSSelectorFromString("getDimmingStep")

if client.responds(to: getDimmingStepSelector)
{
    typealias GetDimmingStep = @convention(c) (AnyObject, Selector) -> Int
    let implementation = client.method(for: getDimmingStepSelector)
    let getDimmingStep = unsafeBitCast(implementation, to: GetDimmingStep.self)
    print("Current dimming step: \(getDimmingStep(client, getDimmingStepSelector))")
}

func printMethods(of inspectedClass: AnyClass, heading: String)
{
    var methodCount: UInt32 = 0

    guard let methods = class_copyMethodList(inspectedClass, &methodCount) else
    {
        print("\(heading): none")
        return
    }

    defer
    {
        free(methods)
    }

    print("\(heading):")

    for index in 0..<Int(methodCount)
    {
        let method = methods[index]
        let selector = method_getName(method)
        let encoding = method_getTypeEncoding(method).map(String.init(cString:)) ?? "?"
        print("  \(NSStringFromSelector(selector))  \(encoding)")
    }
}

printMethods(of: clientClass, heading: "Instance methods")

if let metaClass = object_getClass(clientClass)
{
    printMethods(of: metaClass, heading: "Class methods")
}

var propertyCount: UInt32 = 0

if let properties = class_copyPropertyList(clientClass, &propertyCount)
{
    defer
    {
        free(properties)
    }

    print("Properties:")

    for index in 0..<Int(propertyCount)
    {
        let property = properties[index]
        let name = String(cString: property_getName(property))
        let attributes = property_getAttributes(property).map(String.init(cString:)) ?? "?"
        print("  \(name)  \(attributes)")
    }
}

var ivarCount: UInt32 = 0

if let ivars = class_copyIvarList(clientClass, &ivarCount)
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
        let encoding = ivar_getTypeEncoding(ivar).map(String.init(cString:)) ?? "?"
        print("  \(name)  \(encoding)")
    }
}

if let coreBrightnessIvar = class_getInstanceVariable(
    clientClass,
    "_coreBrightnessClient"
),
   let coreBrightnessClient = object_getIvar(client, coreBrightnessIvar),
   let coreBrightnessClass = object_getClass(coreBrightnessClient)
{
    print("CoreBrightness client class: \(NSStringFromClass(coreBrightnessClass))")

    var currentClass: AnyClass? = coreBrightnessClass

    while let inspectedClass = currentClass
    {
        printMethods(
            of: inspectedClass,
            heading: "Methods on \(NSStringFromClass(inspectedClass))"
        )
        currentClass = class_getSuperclass(inspectedClass)
    }

    var coreIvarCount: UInt32 = 0

    if let coreIvars = class_copyIvarList(coreBrightnessClass, &coreIvarCount)
    {
        defer
        {
            free(coreIvars)
        }

        print("CoreBrightness instance variables:")

        for index in 0..<Int(coreIvarCount)
        {
            let ivar = coreIvars[index]
            let name = ivar_getName(ivar).map(String.init(cString:)) ?? "?"
            let encoding = ivar_getTypeEncoding(ivar).map(String.init(cString:)) ?? "?"
            print("  \(name)  \(encoding)")

            if encoding.hasPrefix("@"),
               let value = object_getIvar(coreBrightnessClient, ivar)
            {
                print("    value: \(value)")
            }
        }
    }
}
else
{
    print("CoreBrightness client is not initialized")
}
