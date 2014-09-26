//
//  RPNViewController.m
//  dropboxIntegrationExample
//
//  Created by Rajeev Kumar on 25/09/14.
//  Copyright (c) 2014 rajeev. All rights reserved.
//

#import "RPNViewController.h"
#import <DBChooser/DBChooser.h>
#import "DropBoxOAuthServiceIntegration.h"

@interface RPNViewController ()

@end



@implementation RPNViewController
{
    NSString * accessTokenFromSession;
    NSMutableArray *dropboxFiles;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self disableOauthIfConnected];
	// Do any additional setup after loading the view, typically from a nib.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self resetView];
}

-(void)resetView
{
    dropboxFiles = [[NSUserDefaults standardUserDefaults] objectForKey:allFilesToken];
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [dropboxFiles count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    NSString *fileName = [dropboxFiles objectAtIndex:indexPath.row];
//    NSString *fileName = fileProps[0];//contains both file name and file path and revisions.
    UILabel *label = (UILabel *)[cell viewWithTag:101];
    label.text = fileName;
    
    NSSet *deletedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:deletedFilesToken];
    NSSet *modifiedFiles = [[NSUserDefaults standardUserDefaults] objectForKey:modifiedFilesToken];
    
    if([deletedFiles containsObject:fileName]){
        label.textColor = [UIColor redColor];
    }else if ([modifiedFiles containsObject:fileName]){
        label.textColor = [UIColor greenColor];
    }
    
//    UIImageView *imageView = (id)[cell viewWithTag:100];
    
//    if(fileProps.count == 4 && ![fileProps[2] isEqualToValue:fileProps[3]]){
//        imageView.hidden = NO;
//    }else {
//         imageView.hidden = YES;
//    }
    return cell;
}


-(void)disableOauthIfConnected
{
    accessTokenFromSession = [[NSUserDefaults standardUserDefaults] objectForKey:accessToken];
    if(accessTokenFromSession != nil){
        self.ouathButton.titleLabel.text = @"oauth connected";
        self.ouathButton.enabled = NO;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)openChooser:(id)sender {
    
    NSString *const dropboxFilesKey = @"dropboxAddedFiles";
    [[DBChooser defaultChooser] openChooserForLinkType:DBChooserLinkTypeDirect
                                    fromViewController:self completion:^(NSArray *results)
     {
         if ([results count]) {
              DBChooserResult *file = results[0];
              NSLog(@"path of the file => %@", file.link);
              NSString *fileUrl = file.link.description;
             
             NSString *fileDecodedUrl = [[fileUrl stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
             NSString *filePath = [fileDecodedUrl substringFromIndex:57];
             
             NSLog(@"file path form root directory => %@", filePath);
             
             //extract file name from the file path
             NSArray *filePathComponents = [filePath componentsSeparatedByString:@"/"];
             NSString *fileName = [filePathComponents objectAtIndex:filePathComponents.count-1];
             
             //Add file to NSUserDefaults
             NSMutableArray *tempFiles = [[NSUserDefaults standardUserDefaults] objectForKey:dropboxFilesKey];
             if(tempFiles == nil){
                 tempFiles = [NSMutableArray new];
             }
             
             NSMutableArray *fileInfo = [[NSMutableArray alloc] initWithObjects:fileName,filePath, nil];
             [tempFiles addObject:fileInfo];
             
             NSMutableSet *tempPathNameSet = [NSMutableSet new];
             NSMutableArray *tempFilesCopy = [tempFiles mutableCopy];
             for(NSArray *fileInfo in tempFiles){
                 if([tempPathNameSet containsObject:fileInfo[1]]){
                     [tempFilesCopy removeObject:fileInfo];
                 }else{
                     [tempPathNameSet addObject:fileInfo[1]];
                 }
             }
  
             //If both file name and file path are same, it is in root folder.
              [[NSUserDefaults standardUserDefaults] setObject:tempFilesCopy forKey:dropboxFilesKey];
         } else {
             NSLog(@"user didn't add file from the dropbox chooser");
         }
     }];
}

- (IBAction)connectOAuth:(id)sender {
    [DropBoxOAuthServiceIntegration getOAuthRequestToken];
}

- (IBAction)checkForUpdates:(id)sender {
    [DropBoxOAuthServiceIntegration getDeltaChanges];
    [self resetView];
    [self.tableView reloadData];
}

- (IBAction)refreshView:(id)sender {
    [self resetView];
    [self.tableView reloadData];
}
@end
