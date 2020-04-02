// main.swift

import Foundation
import ArgumentParser

struct Configure: ParsableCommand {
    public static let configuration = CommandConfiguration(abstract: "Helper for writing config.json file for IoT Platform.")
    
    private let defaultPath = "/var/www/html/config.json"
    
    @Argument(default: nil, help: "Point this to the path of the file")
    private var filePath: String?
    
    func run() throws {
        let realPath: String
        let pathMsg: String
        if let path = self.filePath {
            realPath = path
            pathMsg = "Using config.json file at: \(realPath)"
        } else {
            realPath = self.defaultPath
            pathMsg = "Using config.json at default location: \(realPath)"
        }
        
        print(pathMsg)
        
        var shouldContinue = true
        while shouldContinue {
            // Start executing the program
            shouldContinue = try runCommandTool(realPath)
        }
    }
    
    /// Read stdin and process accordingly
    /// - Returns: A boolean of whether the tool should quit or not
    func runCommandTool(_ filePath: String) throws -> Bool {
        // Start the command
        print(">", terminator: " ")
        
        if let line = readLine() {
            // Exit when needed
            if line == "exit" || line == "quit" {
                return false
            }
            
            // Execute the entered command
            if line == "create" {
                try createFile(at: filePath)
            }
            
            else if line.starts(with: "add") {
                let split = line.split(separator: " ")
                try add(device: String(split[1]), filePath)
            }
                
            else if line.starts(with: "delete") {
                let split = line.split(separator: " ")
                try delete(device: String(split[1]), filePath)
            }
                
            else if line == "list" {
                try listAll(filePath)
            }
                
            else if line.starts(with: "list") {
                let split = line.split(separator: " ")
                try list(String(split[1]), filePath)
            }
            
            else if line == "help" {
                printHelp()
            }
            
            else {
                print("Unknown Command")
            }
        }
        
        return true
    }
    
    func createFile(at location: String) throws {
        // Test whether file already exists, and ask for replacement
        if FileManager.default.fileExists(atPath: location) {
            print("File already exists, replace it? [yes/no] (default:no)", terminator: " ")
            var replace = false
            let line = readLine()
            if line == "y" || line == "yes" {
                replace = true
            }
            
            if !replace {
                print("Keeping original file.")
                return
            }
        }
        
        // Write the file
        print("Creating config.json file at: \(location)")
        let defaultContent = "[]"
        let defaultData = defaultContent.data(using: .utf8)
        let url = URL(fileURLWithPath: location)
        try defaultData?.write(to: url)
        print("Done!")
    }
    
    func add(device paramName: String, _ location: String) throws {
        var jsonData = try openAndDecodeFile(location)
        
        guard jsonData != nil else {
            print("Error: Cannot read config file.")
            return
        }
        
        // Check if device already exists
        let index = jsonData!.firstIndex { object -> Bool in
            return object["parameterName"] as! String == paramName
        }
        
        if index != nil {
            print("Error: device with name \(paramName) already exists!")
            return
        }
        
        print("Adding device with parameter name: \(paramName)")
        
        // Initialize dictionary
        var deviceDict: [String:Any] = ["parameterName":paramName]
        
        print("What should this device be called? (default:\(paramName))", terminator: " ")
        if let line = readLine() {
            deviceDict["displayName"] = line == "" ? paramName : line
        }
        
        print("What is this control's type? (default:switch)", terminator: " ")
        if let line = readLine() {
            deviceDict["type"] = line == "" ? "switch" : line
        }
        
        print("What is the class name of this device? (default:simpleswitch)", terminator: " ")
        if let line = readLine() {
            deviceDict["className"] = line == "" ? "simpleswitch" : line
        }
        
        var enterAdditionalParam = false
        
        print("Enter additional parameter? (default:yes)", terminator: " ")
        if let line = readLine() {
            if line == "y" || line == "yes" || line == "" {
                enterAdditionalParam = true
            }
        }
        
        if enterAdditionalParam {
            while true {
                var shouldContinue = true
                
                // Initial value to pass compilation
                var keyName: String = ""
                var keyType: Int = 0
                var keyValue: Any = ""
                
                print("Enter name of parameter (or return to create device):", terminator: " ")
                if let line = readLine() {
                    if line == "" {
                        shouldContinue = false
                    } else {
                        keyName = line
                    }
                }
                
                // Before adding anything else test whether we should leave this loop first
                if !shouldContinue {
                    break
                }
                
                print("Enter number for corresponding value type:\n1. Text\n2. Number\nEnter here (default:1):", terminator: " ")
                if let line = readLine() {
                    if line == "" {
                        keyType = 1
                    } else {
                        let number = Int(line)
                        if let number = number, (number == 2 || number == 1) {
                            keyType = number
                        } else {
                            print("Invalid number, assuming Text.")
                            keyType = 1
                        }
                    }
                }
                
                print("Enter value for parameter \(keyName):", terminator: " ")
                if let line = readLine() {
                    if keyType == 1 {
                        // Text
                        keyValue = line
                    } else {
                        // Number
                        if let number = Int(line) {
                            keyValue = number
                        } else {
                            keyValue = 0
                        }
                    }
                }
                
                // Add to dict
                deviceDict[keyName] = keyValue
            }
        }
        
        // Add the device
        jsonData!.append(deviceDict)
        
        try write(jsonData!, to: location)
        
        print("Device created successfully!")
    }
    
    func delete(device paramName: String, _ location: String) throws {
        // Read the file first
        var jsonData = try openAndDecodeFile(location)
        
        guard jsonData != nil else {
            print("Error: Cannot read config file.")
            return
        }
        
        // Check if device exists
        // Check if device already exists
        let index = jsonData!.firstIndex { object -> Bool in
            return object["parameterName"] as! String == paramName
        }
        
        if index == nil {
            print("Error: device with name \(paramName) does not exist!")
            return
        }
        
        print("About to delete device \(paramName), continue? (default:no)", terminator: " ")
        
        var shouldDelete = false
        if let line = readLine() {
            if line == "yes" || line == "y" {
                shouldDelete = true
            }
        }
        
        if !shouldDelete {
            print("The device is not deleted.")
            return
        }
        
        print("Deleting \(paramName)...")
        
        jsonData!.remove(at: index!)
        
        try write(jsonData!, to: location)
        
        print("Done!")
    }
    
    func listAll(_ location: String) throws {
        let jsonData = try openAndDecodeFile(location)
        
        guard jsonData != nil else {
            print("Error: Cannot read config file.")
            return
        }
        
        print("\(jsonData!.count) devices total:")
        for device in jsonData! {
            print("- \(device["displayName"]!) (\(device["parameterName"]!))")
        }
    }
    
    func list(_ device: String, _ location: String) throws {
        let jsonData = try openAndDecodeFile(location)
        
        guard jsonData != nil else {
            print("Error: Cannot read config file.")
            return
        }
        
        let index = jsonData!.firstIndex { obj -> Bool in
            return obj["parameterName"] as! String == device
        }
        
        if index == nil {
            print("This device does not exist!")
            return
        }
        
        let deviceInfo = jsonData![index!]
        
        print("Info for: \(device)")
        for (key, value) in deviceInfo {
            print(key, "-", value)
        }
    }
    
    func printHelp() {
        // TODO: Help doc
        print("Helpdoc for iot-config")
        print("This is an interactive tool is intended to help you on writing the config.json file for the platform.")
        print("There are 5 commands: ")
        print("create - create an empty config.json file.")
        print("add <name> - add a device with the specified name, you will need to answer some questions and add any additional parameter needed for the device.")
        print("delete <name> - delete the device with the specified name.")
        print("list - list all devices.")
        print("list <name> - show all properties for device with the specified name.")
        print("help - show this helpdoc.")
    }
    
    func openAndDecodeFile(_ location: String) throws -> [[String:Any]]? {
        // Read file
        let url = URL(fileURLWithPath: location)
        let fileData = try Data(contentsOf: url)
        let jsonData = try JSONSerialization.jsonObject(with: fileData, options: .allowFragments) as? [[String:Any]]
        return jsonData
    }
    
    func write(_ data: [[String:Any]], to path: String) throws {
        let url = URL(fileURLWithPath: path)
        let newJSONData = try JSONSerialization.data(withJSONObject: data, options: [])
        try newJSONData.write(to: url)
    }
}

// Run the command
Configure.main()
