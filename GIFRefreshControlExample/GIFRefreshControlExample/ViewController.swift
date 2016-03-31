//
//  ViewController.swift
//  GIFRefreshControlExample
//
//  Created by Kevin DELANNOY on 01/06/15.
//  Copyright (c) 2015 Kevin Delannoy. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource {
    @IBOutlet private weak var tableView: UITableView!

    var count = 1
    let refreshControl = GIFRefreshControl()

    //MARK: Refresh control

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshControl.animatedImage = GIFAnimatedImage(data: NSData(contentsOfURL: NSBundle.mainBundle().URLForResource("giphy", withExtension: "gif")!)!)
        refreshControl.contentMode = .ScaleAspectFill
        refreshControl.addTarget(self, action: #selector(ViewController.refresh), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }


    //MARK: Refresh

    func refresh() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) { () -> Void in

            self.count += 1
            self.refreshControl.endRefreshing()

            self.tableView.beginUpdates()
            self.tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)],
                withRowAnimation: UITableViewRowAnimation.None)
            self.tableView.endUpdates()
        }
    }


    //MARK: UITableViewDataSource

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCellWithIdentifier("TableViewCell")!
    }
}
