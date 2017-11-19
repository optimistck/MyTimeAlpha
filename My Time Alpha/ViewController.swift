//
//  ViewController.swift
//  My Time Alpha
//
//  Created by Constantin on 12/30/16.
//  Copyright © 2016 Constantin. All rights reserved.
//
// up next: figure out how to capture the current time and the past time.




import UIKit

class ViewController: UIViewController {
    
    var daysRepository = [String: [Double]]()
    var dateEntry = [0.0, 0.0, 0.0, 0.0, 0.0]
    
    // me, family, waste, work, sleep // keeps track of the state of time charging
    var whatsOnNow: [Bool] = [false, false, true, false, false]
    var lastOn: [Bool] = [false, false, true, false, false]
    var appLastRun = Date() //is the date last task was started

    @IBOutlet var timeNowLabel: UILabel!
    @IBOutlet var timeOnCurrentActivityLabel: UILabel!
    
    @IBOutlet var meTimeSwitch: UISwitch!
    @IBOutlet var familyTimeSwitch: UISwitch!
    @IBOutlet var wasteTimeSwitch: UISwitch!
    @IBOutlet var workTimeSwitch: UISwitch!
    @IBOutlet var sleepTimeSwitch: UISwitch!
    
    @IBOutlet var meTimeLabel: UILabel!
    @IBOutlet var familyTimeLabel: UILabel!
    @IBOutlet var wasteTimeLabel: UILabel!
    @IBOutlet var workTimeLabel: UILabel!
    @IBOutlet var sleepTimeLabel: UILabel!
    
    
    let userCalendar = Calendar.current
    //var dateTimeLastActionStarted = Date()
    
    //temp. Need to retrieve the values for a day
    var meTimeTotalSeconds: Double = 0.00
    var familyTimeTotalSeconds: Double = 0.00
    var wasteTimeTotalSeconds: Double = 0.00
    var workTimeTotalSeconds: Double = 0.00
    var sleepTimeTotalSeconds: Double = 0.00
 

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        var timer = Timer()
        
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.timerCalled), userInfo: nil, repeats: true)
        
        //timer.invalidate()
        
        // restore the state of what's on last
        let whatsOnState = UserDefaults.standard.object(forKey: "whatsOnNow")
        
        if let tempItems = whatsOnState as? [Bool] {
            whatsOnNow = tempItems
        }

        //get the last run date
        if let dateLastRun = UserDefaults.standard.object(forKey: "lastRun") as! Date? {
            appLastRun = dateLastRun
        } else {
            appLastRun = Date()
        }
        
        // set switches
        refreshViewOfAllSwitches()
        

        // determine if the app was already run today. If so, load the values. If not, do the adding of the last running action.
        if userCalendar.isDateInToday(appLastRun) {
            // restore the values from the User Defaults
            //let workingDate = getTodaysDate()
            let workingDate = getDateAsString(date: Date())
            if let goodTimes = UserDefaults.standard.object(forKey: "daysRepository") {
                daysRepository = goodTimes as! [String : [Double]]
                
                if let todaysEntry = daysRepository[workingDate] {
                    dateEntry = todaysEntry
                }
            }
        } else if userCalendar.isDateInYesterday(appLastRun) {
            
            addUpTaskDurationThroughMidnight(date: appLastRun)
            appLastRun = userCalendar.startOfDay(for: Date())
            dateEntry = [0.0, 0.0, 0.0, 0.0, 0.0]
            saveTimesPermanently()
            print("app DID run yesterday")
            
        }
        
        else {
            // hold up, before setting the values, need to add the values to the last running action.
            // we know the last running action from the last on
            // we can determine how many days have passed
            // we can populate the values for the last time this was run, plus for today.
            
            dateEntry = [0.0, 0.0, 0.0, 0.0, 0.0]
            appLastRun = Date()
            saveTimesPermanently()
            print("last run was neither today or yesterday. Start from scratch today.")
        }
        
        // update the stats
        refreshAllStatsRefactored()
        
        meTimeSwitch.addTarget(self, action: #selector(ViewController.stateChangedOfMe), for: UIControlEvents.valueChanged)
        familyTimeSwitch.addTarget(self, action: #selector(ViewController.stateChangedOfFamily), for: UIControlEvents.valueChanged)
        wasteTimeSwitch.addTarget(self, action: #selector(ViewController.stateChangedOfWaste), for: UIControlEvents.valueChanged)
        workTimeSwitch.addTarget(self, action: #selector(ViewController.stateChangedOfWork), for: UIControlEvents.valueChanged)
        sleepTimeSwitch.addTarget(self, action: #selector(ViewController.stateChangedOfSleep), for: UIControlEvents.valueChanged)

        //debugDump()
        
    }
    
    func timerCalled() {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "HH:mm:ss"
        timeNowLabel.text = dateFormat.string(from: Date())
        
        var dateToShow = Date()
        var seconds = 0.0
        seconds = dateToShow.timeIntervalSince1970 - appLastRun.timeIntervalSince1970
        let (h0, m0, s0) = secondsToHoursMinutesSeconds(seconds: seconds)
        timeOnCurrentActivityLabel.text = formatTimeText(hours: h0, minutes: m0, seconds: s0)
        
        
        
    }
    
    func stateChangedOfMe(switchState: UISwitch) {
        lastOn = whatsOnNow
        whatsOnNow = [true, false, false, false, false]
        onAnyStateChange()
    }
    func stateChangedOfFamily(switchState: UISwitch) {
        lastOn = whatsOnNow
        whatsOnNow = [false, true, false, false, false]
        onAnyStateChange()
    }
    func stateChangedOfWaste(switchState: UISwitch) {
        lastOn = whatsOnNow
        whatsOnNow = [false, false, true, false, false]
        onAnyStateChange()
    }
    func stateChangedOfWork(switchState: UISwitch) {
        lastOn = whatsOnNow
        whatsOnNow = [false, false, false, true, false]
        onAnyStateChange()
    }
    func stateChangedOfSleep(switchState: UISwitch) {
        lastOn = whatsOnNow
        whatsOnNow = [false, false, false, false, true]
        onAnyStateChange()
    }
    
    func onAnyStateChange() {
        calculateTheDifference()
        refreshViewOfAllSwitches()
        refreshAllStatsRefactored()
        saveTimesPermanently()
    }
    
    func saveTimesPermanently() {
        //update the appLastRun to record the start time of the last task
        appLastRun = Date()
        UserDefaults.standard.set(appLastRun, forKey: "lastRun")
        
        //does the current key (date) exists? If so, add to the array
        //current key doesn't exist? Create a new entry.
        
        
        let aDate = getDateAsString(date: Date())
        daysRepository[aDate] = dateEntry
        UserDefaults.standard.set(daysRepository, forKey: "daysRepository")
    }
    
    
    func getDateAsString(date: Date) -> String {
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "MMMddyyyy"
        let aDate = dateFormat.string(from: date)
        return aDate
    }
    
    func refreshViewOfAllSwitches() {
        meTimeSwitch.isOn = whatsOnNow[0]
        familyTimeSwitch.isOn = whatsOnNow[1]
        wasteTimeSwitch.isOn = whatsOnNow[2]
        workTimeSwitch.isOn = whatsOnNow[3]
        sleepTimeSwitch.isOn = whatsOnNow[4]
    }
    
    func refreshAllStatsRefactored() {
        
        let (h0, m0, s0) = secondsToHoursMinutesSeconds(seconds: dateEntry[0])
        meTimeLabel.text = formatTimeText(hours: h0, minutes: m0, seconds: s0) //"\(Int(h0)):\(Int(m0)):\(Int(s0))"
        UserDefaults.standard.set(dateEntry[0], forKey: "meTime")
        
        let (h1, m1, s1) = secondsToHoursMinutesSeconds(seconds: dateEntry[1])
        familyTimeLabel.text = formatTimeText(hours: h1, minutes: m1, seconds: s1)
        UserDefaults.standard.set(dateEntry[1], forKey: "familyTime")
        
        let (h2, m2, s2) = secondsToHoursMinutesSeconds(seconds: dateEntry[2])
        wasteTimeLabel.text = formatTimeText(hours: h2, minutes: m2, seconds: s2)
        UserDefaults.standard.set(dateEntry[2], forKey: "wasteTime")
        
        let (h3, m3, s3) = secondsToHoursMinutesSeconds(seconds: dateEntry[3])
        workTimeLabel.text = formatTimeText(hours: h3, minutes: m3, seconds: s3)
        UserDefaults.standard.set(dateEntry[3], forKey: "workTime")
        
        let (h4, m4, s4) = secondsToHoursMinutesSeconds(seconds: dateEntry[4])
        sleepTimeLabel.text = formatTimeText(hours: h4, minutes: m4, seconds: s4)
        UserDefaults.standard.set(dateEntry[4], forKey: "sleepTime")
    }
    
    func formatTimeText(hours: Double, minutes: Double, seconds: Double) -> (String) {
        var textToReturn = ""
        
        if hours != 0 {
            textToReturn.append("\(Int(hours)) hrs ")
        }
        
        if minutes != 0 {
            textToReturn.append("\(Int(minutes)) mins ")
        } else if seconds != 0 {
            textToReturn.append("\(Int(seconds)) secs")
        }
        
        return textToReturn
    }
    
    func calculateTheDifference() {
        
        let timeNow = Date()
        var tTime = 0.0
        
        //save state
        UserDefaults.standard.set(whatsOnNow, forKey: "whatsOnNow")
        UserDefaults.standard.set(lastOn, forKey: "whatsLastOn")
        
        //look at who was "on" last and record the time.
        for activity in lastOn {
            if activity {
                tTime = dateEntry[lastOn.index(of: activity)!]
                tTime = tTime + (timeNow.timeIntervalSince1970 - appLastRun.timeIntervalSince1970)
                dateEntry[lastOn.index(of: activity)!] = tTime
            }
        }
        
        //reset the timer
        appLastRun = timeNow


    }
    
                //the the last running action has occurred yesterday, then calculate the time between the last running action and the start of today, and add that to yesterday's array, and save.
    func addUpTaskDurationThroughMidnight(date: Date) {
        
        var tTime = 0.0
        var tempDaysRepository = [String: [Double]]()
        var tempDateEntry = [0.0, 0.0, 0.0, 0.0, 0.0]
        let todaysDate = Date()
        let midnight = userCalendar.startOfDay(for: todaysDate)
        
        //var midnight = userCalendar.startOfDay(for: dateTimeNow
        
        //load yesterday's array...
        let workingDate = getDateAsString(date: date)
        print("DEBUG: workingDate -  \(workingDate)")
        if let goodTimes = UserDefaults.standard.object(forKey: "daysRepository") {
            tempDaysRepository = goodTimes as! [String : [Double]]
            print("DEBUG: pull the dictionary daysRepository -  \(goodTimes)")
            if let otherDayEntry = daysRepository[workingDate] {
                tempDateEntry = otherDayEntry
                print("DEBUG: yes, the \(workingDate) exists in the dict")
            }
        }
        
        //look at who was "on" last and record the time. This is onload and we're taking whatsOneNow, because the activity is still running.
        for activity in whatsOnNow {
            if activity {
                //need to load yesterday's dateEntry array.
                tTime = tempDateEntry[whatsOnNow.index(of: activity)!]
                tTime = tTime + (midnight.timeIntervalSince1970 - date.timeIntervalSince1970)
                dateEntry[whatsOnNow.index(of: activity)!] = tTime
            }
        } //at this point the time the last task that started yesterday, but not finished today, is accounted for yesterday's status from start time of yesterday to today. But we also now need to make the start time of this new task as midnight.
    }



    
    
    func secondsToHoursMinutesSeconds (seconds : Double) -> (Double, Double, Double) {
        let (hr,  minf) = modf (seconds / 3600)
        let (min, secf) = modf (60 * minf)
        return (hr, min, 60 * secf)
    }
    
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func debugDump() {
        print(" daysRepository \(daysRepository)")
        print(" dateEntry \(dateEntry)")
        print(" whatsOnNow\(whatsOnNow)")
        print(" lastOn\(lastOn)")
        print(" appLastRun\(appLastRun)")
        print(" appLastRun \(appLastRun)")
        if let goodTimes = UserDefaults.standard.object(forKey: "daysRepository") {
            print("retrieved daysRepository from User Settings \(goodTimes)")
        }
        //print(" \()")
        
    }
    

}

