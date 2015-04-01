////////////////////////////////////////////////////////////////////////////
//
// Copyright 2015 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import XCTest
import RealmSwift

#if !DEBUG

private func createStringObjects(factor: Int) -> Realm {
    let realm = Realm(inMemoryIdentifier: factor.description)
    realm.write {
        for _ in 0..<(1000 * factor) {
            realm.create(SwiftStringObject.self, value: ["a"])
            realm.create(SwiftStringObject.self, value: ["b"])
        }
    }
    return realm
}
private var smallRealm: Realm!
private var mediumRealm: Realm!
private var largeRealm: Realm!

class SwiftPerformanceTests: TestCase {
    override class func setUp() {
        super.setUp()
        autoreleasepool {
            smallRealm = createStringObjects(1)
            mediumRealm = createStringObjects(5)
            largeRealm = createStringObjects(50)
        }
    }

    override class func tearDown() {
        smallRealm = nil
        mediumRealm = nil
        largeRealm = nil
        super.tearDown()
    }

    override func measureBlock(block: (() -> Void)!) {
        super.measureBlock {
            autoreleasepool {
                block()
            }
        }
    }

    override func measureMetrics(metrics: [AnyObject]!, automaticallyStartMeasuring: Bool, forBlock block: (() -> Void)!) {
        super.measureMetrics(metrics, automaticallyStartMeasuring: automaticallyStartMeasuring) {
            autoreleasepool {
                block()
            }
        }
    }

    func inMeasureBlock(block: () -> ()) {
        measureMetrics(self.dynamicType.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) {
            _ = block()
        }
    }

    func testInsertMultiple() {
        inMeasureBlock {
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            realm.write {
                for _ in 0..<5000 {
                    let obj = SwiftStringObject()
                    obj.stringCol = "a"
                    realm.add(obj)
                }
            }
            self.stopMeasuring()
            self.tearDown()
        }
    }

    func testInsertSingleLiteral() {
        inMeasureBlock {
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            for _ in 0..<50 {
                realm.write {
                    _ = realm.create(SwiftStringObject.self, value: ["a"])
                }
            }
            self.stopMeasuring()
            self.tearDown()
        }
    }

    func testInsertMultipleLiteral() {
        inMeasureBlock {
            let realm = self.realmWithTestPath()
            self.startMeasuring()
            realm.write {
                for _ in 0..<5000 {
                    realm.create(SwiftStringObject.self, value: ["a"])
                }
            }
            self.stopMeasuring()
            self.tearDown()
        }
    }

    func getStringObjects(factor: Int) -> Realm {
        let realm = Realm(inMemoryIdentifier: factor.description)
        NSFileManager.defaultManager().removeItemAtPath(testRealmPath(), error: nil)
        realm.writeCopyToPath(testRealmPath())
        return realmWithTestPath()
    }

    func testCountWhereQuery() {
        let realm = getStringObjects(50)
        measureBlock {
            let results = realm.objects(SwiftStringObject).filter("stringCol = 'a'")
            _ = results.count
        }
    }

    func testCountWhereTableView() {
        let realm = getStringObjects(50)
        measureBlock {
            let results = realm.objects(SwiftStringObject).filter("stringCol = 'a'")
            _ = results.first
            _ = results.count
        }
    }

    func testEnumerateAndAccessQuery() {
        let realm = getStringObjects(5)
        measureBlock {
            for stringObject in realm.objects(SwiftStringObject).filter("stringCol = 'a'") {
                let string = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessAll() {
        let realm = getStringObjects(5)
        measureBlock {
            for stringObject in realm.objects(SwiftStringObject) {
                let string = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessAllSlow() {
        let realm = getStringObjects(5)
        measureBlock {
            let results = realm.objects(SwiftStringObject)
            for i in 0..<results.count {
                let string = results[i].stringCol
            }
        }
    }

    func testEnumerateAndAccessArrayProperty() {
        let realm = getStringObjects(5)
        realm.beginWrite()
        let arrayPropertyObject = realm.create(SwiftArrayPropertyObject.self, value: ["name", map(realm.objects(SwiftStringObject)) { $0 }, []])
        realm.commitWrite()

        measureBlock {
            for stringObject in arrayPropertyObject.array {
                let string = stringObject.stringCol
            }
        }
    }

    func testEnumerateAndAccessArrayPropertySlow() {
        let realm = getStringObjects(5)
        realm.beginWrite()
    let arrayPropertyObject = realm.create(SwiftArrayPropertyObject.self, value: ["name", map(realm.objects(SwiftStringObject)) { $0 }, []])
        realm.commitWrite()

        measureBlock {
            let list = arrayPropertyObject.array
            for i in 0..<list.count {
                let string = list[i].stringCol
            }
        }
    }

    func testEnumerateAndMutateAll() {
        let realm =  getStringObjects(10)
        measureBlock {
            realm.write {
                for stringObject in realm.objects(SwiftStringObject) {
                    stringObject.stringCol = "c"
                }
            }
        }
    }

    func testEnumerateAndMutateQuery() {
        let realm =  getStringObjects(1)
        measureBlock {
            realm.write {
                for stringObject in realm.objects(SwiftStringObject).filter("stringCol != 'b'") {
                    stringObject.stringCol = "c"
                }
            }
        }
    }

    func testQueryConstruction() {
        let realm = realmWithTestPath()
        let predicate = NSPredicate(format: "boolCol = false and (intCol = 5 or floatCol = 1.0) and objectCol = nil and doubleCol != 7.0 and stringCol IN {'a', 'b', 'c'}")!

        measureBlock {
            for _ in 0..<100 {
                _ = realm.objects(SwiftObject).filter(predicate)
            }
        }
    }

    func testDeleteAll() {
        inMeasureBlock {
            let realm = self.getStringObjects(5)
            self.startMeasuring()
            realm.write {
                realm.delete(realm.objects(SwiftStringObject))
            }
            self.stopMeasuring()
        }
    }

    func testQueryDeletion() {
        inMeasureBlock {
            let realm = self.getStringObjects(5)
            self.startMeasuring()
            realm.write {
                realm.delete(realm.objects(SwiftStringObject).filter("stringCol = 'a' OR stringCol = 'b'"))
            }
            self.stopMeasuring()
        }
    }

    func testManualDeletion() {
        inMeasureBlock {
            let realm = self.getStringObjects(5)
            let objects = map(realm.objects(SwiftStringObject)) { $0 }
            self.startMeasuring()
            realm.write {
                realm.delete(objects)
            }
            self.stopMeasuring()
        }
    }

    func testUnindexedStringLookup() {
        let realm = realmWithTestPath()
        realm.write {
            for i in 0..<1000 {
                realm.create(SwiftStringObject.self, value: [i.description])
            }
        }
        measureBlock {
            for i in 0..<1000 {
                realm.objects(SwiftStringObject).filter("stringCol = %@", i.description).first
            }
        }
    }

    func testIndexedStringLookup() {
        let realm = realmWithTestPath()
        realm.write {
            for i in 0..<1000 {
                realm.create(SwiftIndexedPropertiesObject.self, value: [i.description, i])
            }
        }
        measureBlock {
            for i in 0..<1000 {
                realm.objects(SwiftIndexedPropertiesObject).filter("stringCol = %@", i.description).first
            }
        }
    }

    func testLargeINQuery() {
        let realm = realmWithTestPath()
        realm.beginWrite()
        var ids = [Int]()
        for i in 0..<2000 {
            realm.create(SwiftIntObject.self, value: [i])
            if i % 2 != 0 {
                ids.append(i)
            }
        }
        realm.commitWrite()
        measureBlock {
            _ = realm.objects(SwiftIntObject).filter("intCol IN %@", ids).first
        }
    }

    func testSortingAllObjects() {
        let realm = realmWithTestPath()
        realm.write {
            for _ in 0..<2000 {
                let randomNumber = Int(arc4random_uniform(UInt32(INT_MAX)))
                realm.create(SwiftIntObject.self, value: [randomNumber])
            }
        }
        measureBlock {
            _ = realm.objects(SwiftIntObject).sorted("intCol", ascending: true).last
        }
    }

    func testRealmCreationCached() {
        var realm: Realm!
        let queue = dispatch_queue_create("test queue", nil)
        dispatch_async(queue) {
            realm = self.realmWithTestPath()
        }
        dispatch_sync(queue) {}

        measureBlock {
            for _ in 0..<250 {
                autoreleasepool {
                    _ = self.realmWithTestPath()
                }
            }
        }
        _ = realm.path
    }

    func testRealmCreationUncached() {
        measureBlock {
            for _ in 0..<50 {
                autoreleasepool {
                    _ = self.realmWithTestPath()
                }
            }
        }
    }

    func testCommitWriteTransaction() {
        inMeasureBlock {
            let realm = Realm(inMemoryIdentifier: "test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            realm.commitWrite()

            self.startMeasuring()
            while object.intCol < 100 {
                realm.write { _ = object.intCol++ }
            }
            self.stopMeasuring()
        }
    }

    func testCommitWriteTransactionWithLocalNotification() {
        inMeasureBlock {
            let realm = Realm(inMemoryIdentifier: "test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            realm.commitWrite()

            let token = realm.addNotificationBlock { _, _ in }
            self.startMeasuring()
            while object.intCol < 100 {
                realm.write { _ = object.intCol++ }
            }
            self.stopMeasuring()
            realm.removeNotification(token)
        }
    }

    func testCommitWriteTransactionWithCrossThreadNotification() {
        let stopValue = 100
        inMeasureBlock {
            let realm = Realm(inMemoryIdentifier: "test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            realm.commitWrite()

            let queue = dispatch_queue_create("background", nil)
            let semaphore = dispatch_semaphore_create(0)
            dispatch_async(queue) {
                let realm = Realm(inMemoryIdentifier: "test")
                let object = realm.objects(SwiftIntObject).first!
                var stop = false
                let token = realm.addNotificationBlock { _, _ in
                    stop = object.intCol == stopValue
                }
                dispatch_semaphore_signal(semaphore)
                while !stop {
                    NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() as NSDate)
                }
                realm.removeNotification(token)
            }

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            self.startMeasuring()
            while object.intCol < stopValue {
                realm.write { _ = object.intCol++ }
            }
            dispatch_sync(queue) {}
            self.stopMeasuring()
        }
    }

    func testCrossThreadSyncLatency() {
        let stopValue = 100
        inMeasureBlock {
            let realm = Realm(inMemoryIdentifier: "test")
            realm.beginWrite()
            let object = realm.create(SwiftIntObject)
            realm.commitWrite()

            let queue = dispatch_queue_create("background", nil)
            let semaphore = dispatch_semaphore_create(0)
            dispatch_async(queue) {
                let realm = Realm(inMemoryIdentifier: "test")
                let object = realm.objects(SwiftIntObject).first!
                let token = realm.addNotificationBlock { _, _ in
                    if object.intCol % 2 == 0 && object.intCol < stopValue {
                        realm.write { _ = object.intCol++ }
                    }
                }
                dispatch_semaphore_signal(semaphore)
                while object.intCol < stopValue {
                    NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() as NSDate)
                }
                realm.removeNotification(token)
            }

            let token = realm.addNotificationBlock { _, _ in
                if object.intCol % 2 == 1 && object.intCol < stopValue {
                    realm.write { _ = object.intCol++ }
                }
            }

            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
            self.startMeasuring()
            realm.write { _ = object.intCol++ }
            while object.intCol < stopValue {
                NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture() as NSDate)
            }
            dispatch_sync(queue) {}
            self.stopMeasuring()
            realm.removeNotification(token)
        }
    }
}

#endif