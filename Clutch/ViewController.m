//
//  ViewController.m
//  Clutch
//
//  Created by Harrison White on 2/25/18.
//  Copyright © 2018 Harrison White. All rights reserved.
//

/*
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ViewController.h"
#import "Clutch.h"
#import <ServiceManagement/ServiceManagement.h>

NSString* kSavedTextKey = @"Saved Text";
NSString* kHelpShownKey = @"Help Shown3";

NSString* kClutchAgentBundleID  = @"com.rcx.clutchagent";

@interface ViewController () <NSControlTextEditingDelegate>

@property (nonatomic, strong) IBOutlet NSComboBox* interfaceDropdown;
@property (nonatomic, strong) IBOutlet NSButton* bindButton;
@property (nonatomic, strong) IBOutlet NSTextField* statusLabel;
@property (nonatomic, strong) IBOutlet NSButton* openClutchAgentAtLoginButton;
@property (nonatomic, strong) NSMutableArray* interfaces;
@property (nonatomic, strong) Clutch* clutch;

@end

@implementation ViewController

- (IBAction)bindToInterfaceClicked:(id)sender {
    if ([_clutch getBindInterface]) {
        NSLog(@"unbinding");
        [_clutch unbindFromInterface];
    }
    else {
        NSLog(@"binding");
        [_clutch bindToInterfaceWithName:_interfaceDropdown.stringValue];
    }
    
    [self saveText];
    [self updateInterfaceDropdown];
}

- (IBAction)helpItemClicked:(id)sender {
    [self showHelp];
}

- (void)showHelp {
    [self performSegueWithIdentifier:@"showHelp" sender:nil];
}

- (void)saveText {
    // _interfaceDropdown.currentEditor.selectedRange = NSMakeRange(0, _interfaceDropdown.stringValue.length);
    
    // save the text
    NSUserDefaults* defaults = [_clutch clutchGroupDefaults];
    [defaults setObject:_interfaceDropdown.stringValue forKey:kSavedTextKey];
    [defaults synchronize];
}

- (void)mouseDown:(NSEvent *)theEvent {
    // deselect the text field
    [self.view.window makeFirstResponder:nil];
    
    [self saveText];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    [self saveText];
    return YES;
}

- (IBAction)interfaceSelected:(NSComboBox *)sender {
    // in the list, the ip address and other info is shown
    // however, once the item is selected, only enter the name in the box
    
    // this shows the user that, for a manual entry, they only need to enter the name of the interface
    
    NSInteger index = _interfaceDropdown.indexOfSelectedItem;
    if (index >= 0 && index < _interfaces.count) {
        ClutchInterface* selectedInterface = [_interfaces objectAtIndex:_interfaceDropdown.indexOfSelectedItem];
        _interfaceDropdown.stringValue = selectedInterface.name;
    }
}

- (IBAction)openAtLoginCheckboxChanged:(NSButton *)sender {
    // Ignore deprecated warnings
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    LSSharedFileListItemRef clutchAgentLoginItem = nil;
    LSSharedFileListRef loginItemsList = nil;
    [self getClutchAgentLoginItem:&clutchAgentLoginItem loginItemsList:&loginItemsList];
    
    if (sender.state == NSOnState && !clutchAgentLoginItem && loginItemsList) {
        // login item does not exist; add
        
        NSURL* clutchAgentURL = [NSURL fileURLWithPath:[self clutchAgentPath]];
        clutchAgentLoginItem = LSSharedFileListInsertItemURL(loginItemsList, kLSSharedFileListItemBeforeFirst, NULL, NULL, (__bridge CFURLRef)clutchAgentURL, NULL, NULL);
        if (!clutchAgentLoginItem) {
            NSLog(@"error adding login item!");
        }
    }
    else if (sender.state == NSOffState && clutchAgentLoginItem && loginItemsList) {
        // login item exists; remove
        LSSharedFileListItemRemove(loginItemsList, clutchAgentLoginItem);
    }
    
    CFRelease(loginItemsList); // don't forget to release memory
#pragma GCC diagnostic pop
}

- (void)getClutchAgentLoginItem:(LSSharedFileListItemRef *)clutchAgentLoginItem loginItemsList:(LSSharedFileListRef *)loginItemsList {
    // This didn't seem to work when I tried it. Perhaps it only works with sandboxed apps.
    // SMLoginItemSetEnabled((__bridge CFStringRef)@"com.rcx.clutchagent", sender.state == NSOnState);
    
    // Arq has this functionality so I opened it in ida64, and it uses the LSSharedFileList APIs instead.
    // These have been deprecated, but since the latest version of Arq still uses them, perhaps they haven't found
    // a solution to this problem either. In any case, I know that LSSharedFileList still works for now.
    
    // I have included a "Copy Files" build phase that will copy a release build of ClutchAgent.app
    // into the Contents/Library/LoginItems dir of the build automatically.
    // Otherwise, this function WILL NOT WORK until ClutchAgent.app is placed in Contents/Library/LoginItems in the app bundle
    
    // The following was straight reverse-engineered from Arq in ida64
    
    // Ignore deprecated warnings
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    LSSharedFileListRef loginItemsListRef = LSSharedFileListCreate(CFAllocatorGetDefault(), kLSSharedFileListSessionLoginItems, nil);
    
    if (loginItemsListRef) {
        // output login items so other methods can add/remove items
        if (loginItemsList != nil) {
            *loginItemsList = loginItemsListRef;
        }
        
        UInt32 loginItemsSnapshotSeed;
        NSArray* loginItems = (__bridge NSArray *)LSSharedFileListCopySnapshot(loginItemsListRef, &loginItemsSnapshotSeed);
        
        NSURL* clutchAgentURL = [NSURL fileURLWithPath:[self clutchAgentPath]];
        
        for (int i = 0; i < loginItems.count; i++) {
            LSSharedFileListItemRef itemRef = (__bridge LSSharedFileListItemRef)[loginItems objectAtIndex:i];
            CFURLRef itemURL;
            FSRef itemFSRef;
            OSStatus status = LSSharedFileListItemResolve(itemRef, kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes, &itemURL, &itemFSRef);
            if (status == 0) {
                // resolved item
                NSURL* itemNSURL = (__bridge NSURL *)itemURL;
                if ([itemNSURL.absoluteString isEqualToString:clutchAgentURL.absoluteString]) {
                    // matched; output clutch agent login item
                    *clutchAgentLoginItem = itemRef;
                    break;
                }
            }
        }
    }
#pragma GCC diagnostic pop
}

- (NSString *)clutchAgentPath {
    NSArray *pathComponents = [[[NSBundle mainBundle]bundlePath]pathComponents];
    NSString *path = [NSString pathWithComponents:[pathComponents arrayByAddingObjectsFromArray:@[ @"Contents", @"Library", @"LoginItems", @"ClutchAgent.app" ]]];
    return path;
}

- (void)launchClutchAgent {
    // This causes the main window to be unable to get focus if called from -viewDidLoad
    
    // only launch Clutch Agent if it isn't already running
    // otherwise, the main window will lose focus, and sometimes it cannot be
    // re-selected without restarting the app! (possible macOS bug?)
    if ([[NSRunningApplication runningApplicationsWithBundleIdentifier:kClutchAgentBundleID]count] == 0) {
        [[NSWorkspace sharedWorkspace]launchApplication:[self clutchAgentPath]];
    }
}

- (NSString *)humanReadableNameFromInterface:(ClutchInterface *)interface {
    return [NSString stringWithFormat:@"%@ - %@", interface.name, interface.address];
}

- (void)updateInterfaceDropdown {
    // select bound interface
    ClutchInterface* bindInterface = [_clutch getBindInterface];
    
    if (bindInterface) {
        // update ui
        _interfaceDropdown.stringValue = bindInterface.name;
        _interfaceDropdown.enabled = NO;
        _bindButton.title = @"Unbind Transmission from Interface";
        
        _statusLabel.stringValue = [NSString stringWithFormat:@"Binding to %@", _interfaceDropdown.stringValue];
        _statusLabel.textColor = [NSColor colorWithRed:0 green:0.4 blue:0 alpha:1];
    }
    else {
        // update interfaces
        [_interfaces setArray:[_clutch getInterfaces]];
        
        // populate list of interface names with info
        NSMutableArray* interfaceNames = [[NSMutableArray alloc]init];
        for (ClutchInterface* interface in _interfaces) {
            NSString* name = [self humanReadableNameFromInterface:interface];
            NSLog(@"adding %@...", name);
            [interfaceNames addObject:name];
        }
        
        // refresh interface dropdown
        [_interfaceDropdown removeAllItems];
        [_interfaceDropdown addItemsWithObjectValues:interfaceNames];
        
        // load the last text that was in the text field
        NSString* savedText = [[_clutch clutchGroupDefaults]objectForKey:kSavedTextKey];
        if (savedText) {
            _interfaceDropdown.stringValue = savedText;
        }
        
        // update ui
        _interfaceDropdown.enabled = YES;
        _bindButton.title = @"Bind Transmission to Interface";
        
        _statusLabel.stringValue = @"Not Binding";
        _statusLabel.textColor = [NSColor blackColor];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    _interfaces = [[NSMutableArray alloc]init];
    _clutch = [[Clutch alloc]init];
    
    [self updateInterfaceDropdown];
    
    // update "open clutch agent at login" checkbox
    LSSharedFileListItemRef clutchAgentLoginItem = nil;
    LSSharedFileListRef loginItemsList = nil;
    [self getClutchAgentLoginItem:&clutchAgentLoginItem loginItemsList:&loginItemsList];
    _openClutchAgentAtLoginButton.state = (clutchAgentLoginItem ? NSOnState : NSOffState);
    CFRelease(loginItemsList); // don't forget to release memory
    
    // launch agent if it isn't running
    [self launchClutchAgent];
}

- (void)viewDidAppear {
    // show help if this is the first launch
    // this is done in -viewDidAppear because the window needs to exist first
    
    NSUserDefaults* defaults = [_clutch clutchGroupDefaults];
    if (![defaults boolForKey:kHelpShownKey]) {
        [self showHelp];
        
        [defaults setBool:YES forKey:kHelpShownKey];
        [defaults synchronize];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
