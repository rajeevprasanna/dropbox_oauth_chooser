//
//  RPNViewController.h
//  dropboxIntegrationExample
//
//  Created by Rajeev Kumar on 25/09/14.
//  Copyright (c) 2014 rajeev. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RPNViewController : UIViewController<UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UIButton *ouathButton;

- (IBAction)openChooser:(id)sender;
- (IBAction)connectOAuth:(id)sender;

- (IBAction)checkForUpdates:(id)sender;
- (IBAction)refreshView:(id)sender;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
