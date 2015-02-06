/*
 * CCController
 *
 * Copyright (c) 2015 Scott Lembcke
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "ccMacros.h"
#import "CCController.h"

#if __CC_PLATFORM_IOS

@implementation CCController
@end

#endif

#if __CC_PLATFORM_MAC

#import "CCController.h"
#import <GameController/GCExtendedGamepad.h>

#include <IOKit/hid/IOHIDLib.h>


const float DeadZonePercent = 0.2f;


@implementation CCController {
	GCExtendedGamepadSnapShotDataV100 _snapshot;
	GCExtendedGamepadSnapshot *_gamepad;
	
	CFIndex _lThumbXUsageID;
	CFIndex _lThumbYUsageID;
	CFIndex _rThumbXUsageID;
	CFIndex _rThumbYUsageID;
	CFIndex _lTriggerUsageID;
	CFIndex _rTriggerUsageID;
	
	BOOL _usesHatSwitch;
	CFIndex _dpadLUsageID;
	CFIndex _dpadRUsageID;
	CFIndex _dpadDUsageID;
	CFIndex _dpadUUsageID;
	
	CFIndex _buttonPauseUsageID;
	CFIndex _buttonAUsageID;
	CFIndex _buttonBUsageID;
	CFIndex _buttonXUsageID;
	CFIndex _buttonYUsageID;
	CFIndex _lShoulderUsageID;
	CFIndex _rShoulderUsageID;
}

@synthesize controllerPausedHandler = _controllerPausedHandler;
@synthesize vendorName = _vendorName;
@synthesize playerIndex = _playerIndex;

static IOHIDManagerRef HID_MANAGER = NULL;
static NSMutableArray *CONTROLLERS = nil;

//MARK: Class methods

+(void)initialize
{
	if(self != [CCController class]) return;
	
	HID_MANAGER = IOHIDManagerCreate(kCFAllocatorDefault, 0);
	CONTROLLERS = [NSMutableArray array];

	if (IOHIDManagerOpen(HID_MANAGER, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
		NSLog(@"Error initializing CCGameController");
		return;
	}
	
	// Register to get callbacks when gamepads are connected.
	NSArray *matches = @[
		@{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_GamePad)},
		@{@(kIOHIDDeviceUsagePageKey): @(kHIDPage_GenericDesktop), @(kIOHIDDeviceUsageKey): @(kHIDUsage_GD_MultiAxisController)},
	];
	
	IOHIDManagerSetDeviceMatchingMultiple(HID_MANAGER, (__bridge CFArrayRef)matches);
	IOHIDManagerRegisterDeviceMatchingCallback(HID_MANAGER, ControllerConnected, NULL);
	
	// Pump the event loop to list all of the currently connected gamepads.
	NSString *mode = @"CCControllerPollGamepads";
	IOHIDManagerScheduleWithRunLoop(HID_MANAGER, CFRunLoopGetCurrent(), (__bridge CFStringRef)mode);
	
	while(CFRunLoopRunInMode((CFStringRef)mode, 0, TRUE) == kCFRunLoopRunHandledSource){}

	IOHIDManagerUnscheduleFromRunLoop(HID_MANAGER, CFRunLoopGetCurrent(), (__bridge CFStringRef)mode);
	
	// Schedule the HID manager normally to get callbacks during runtime.
	IOHIDManagerScheduleWithRunLoop(HID_MANAGER, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
	
	NSLog(@"CCController initialized.");
}

+ (NSArray *)controllers;
{
	
	return [[super controllers] arrayByAddingObjectsFromArray:CONTROLLERS];
}

//MARK: Lifecycle

-(instancetype)initWithDevice:(IOHIDDeviceRef)device
{
	if((self = [super init])){
		NSString *manufacturer = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDManufacturerKey));
		NSString *product = (__bridge NSString *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey));
		_vendorName = [NSString stringWithFormat:@"%@ %@", manufacturer, product];
		
		_snapshot.version = 0x0100;
		_snapshot.size = sizeof(_snapshot);

		_gamepad = [[GCExtendedGamepadSnapshot alloc] init];
		_gamepad.snapshotData = NSDataFromGCExtendedGamepadSnapShotDataV100(&_snapshot);
	}
	
	return self;
}

static IOHIDElementRef
GetAxis(IOHIDDeviceRef device, CFIndex axis)
{
	NSDictionary *match = @{
		@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop),
		@(kIOHIDElementUsageKey): @(axis),
	};
	
	NSArray *elements = CFBridgingRelease(IOHIDDeviceCopyMatchingElements(device, (__bridge CFDictionaryRef)match, 0));
	if(elements.count != 1) NSLog(@"Warning. Oops, didn't find exactly one axis?");
	
	return (__bridge IOHIDElementRef)elements[0];
}

static void
SetupAxis(IOHIDDeviceRef device, IOHIDElementRef element, CFIndex dmin, CFIndex dmax, CFIndex rmin, CFIndex rmax, float deadZonePercent)
{
	IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationMinKey), (__bridge CFTypeRef)@(dmin));
	IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationMaxKey), (__bridge CFTypeRef)@(dmax));
	
	IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationSaturationMinKey), (__bridge CFTypeRef)@(rmin));
	IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationSaturationMaxKey), (__bridge CFTypeRef)@(rmax));
	
	if(deadZonePercent > 0.0f){
		CFIndex mid = (rmin + rmax)/2;
		CFIndex deadZone = (rmax - rmin)*(deadZonePercent/2.0f);
		
		IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationDeadZoneMinKey), (__bridge CFTypeRef)@(mid - deadZone));
		IOHIDElementSetProperty(element, CFSTR(kIOHIDElementCalibrationDeadZoneMaxKey), (__bridge CFTypeRef)@(mid + deadZone));
	}
}

static void
ControllerConnected(void *context, IOReturn result, void *sender, IOHIDDeviceRef device)
{
	if(result == kIOReturnSuccess){
//		NSURL *url = [[NSBundle mainBundle] URLForResource:@"CCControllerConfig.plist" withExtension:nil];
//		NSDictionary *config = [NSDictionary dictionaryWithContentsOfURL:url];
//		
//		NSAssert(@"CCControllerConfig.plist not found.");
		
		CCController *controller = [[CCController alloc] initWithDevice:device];
		
		NSArray *matches = @[
			@{@(kIOHIDElementUsagePageKey): @(kHIDPage_GenericDesktop)},
			@{@(kIOHIDElementUsagePageKey): @(kHIDPage_Button)},
		];
		
		NSUInteger vid = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) unsignedIntegerValue];
		NSUInteger pid = [(__bridge NSNumber *)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)) unsignedIntegerValue];
		
		CFIndex axisMin = 0;
		CFIndex axisMax = 256;
		
		if(vid == 0x054C){ // Sony
			if(pid == 0x5C4){ // DualShock 4
				NSLog(@"[CCController initWithDevice:] Sony Dualshock 4 detected.");
				
				controller->_lThumbXUsageID = kHIDUsage_GD_X;
				controller->_lThumbYUsageID = kHIDUsage_GD_Y;
				controller->_rThumbXUsageID = kHIDUsage_GD_Z;
				controller->_rThumbYUsageID = kHIDUsage_GD_Rz;
				controller->_lTriggerUsageID = kHIDUsage_GD_Rx;
				controller->_rTriggerUsageID = kHIDUsage_GD_Ry;
				
				controller->_usesHatSwitch = YES;
				
				controller->_buttonPauseUsageID = 0x0A;
				controller->_buttonAUsageID = 0x02;
				controller->_buttonBUsageID = 0x03;
				controller->_buttonXUsageID = 0x01;
				controller->_buttonYUsageID = 0x04;
				controller->_lShoulderUsageID = 0x05;
				controller->_rShoulderUsageID = 0x06;
			}
		} else if(vid == 0x045E){ // Microsoft
			if(pid == 0x028E || pid == 0x028F){ // 360 wired/wireless
				NSLog(@"[CCController initWithDevice:] Microsoft Xbox 360 controller detected.");
				
				axisMin = -(1<<15);
				axisMax =  (1<<15);
				
				controller->_lThumbXUsageID = kHIDUsage_GD_X;
				controller->_lThumbYUsageID = kHIDUsage_GD_Y;
				controller->_rThumbXUsageID = kHIDUsage_GD_Rx;
				controller->_rThumbYUsageID = kHIDUsage_GD_Ry;
				controller->_lTriggerUsageID = kHIDUsage_GD_Z;
				controller->_rTriggerUsageID = kHIDUsage_GD_Rz;
				
				controller->_dpadLUsageID = 0x0E;
				controller->_dpadRUsageID = 0x0F;
				controller->_dpadDUsageID = 0x0D;
				controller->_dpadUUsageID = 0x0C;
				
				controller->_buttonPauseUsageID = 0x09;
				controller->_buttonAUsageID = 0x01;
				controller->_buttonBUsageID = 0x02;
				controller->_buttonXUsageID = 0x03;
				controller->_buttonYUsageID = 0x04;
				controller->_lShoulderUsageID = 0x05;
				controller->_rShoulderUsageID = 0x06;
			}
		}
		
		// TODO can we do anything sensible with this?
//		else if(vid == 0x057E){ // Nintendo
//			if(pid == 0x0306){
//				NSLog(@"[CCController initWithDevice:] Nintendo Wiimote detected.");
//			}
//		}

		SetupAxis(device, GetAxis(device, controller->_lThumbXUsageID), -1.0,  1.0, axisMin, axisMax, DeadZonePercent);
		SetupAxis(device, GetAxis(device, controller->_lThumbYUsageID),  1.0, -1.0, axisMin, axisMax, DeadZonePercent);
		SetupAxis(device, GetAxis(device, controller->_rThumbXUsageID), -1.0,  1.0, axisMin, axisMax, DeadZonePercent);
		SetupAxis(device, GetAxis(device, controller->_rThumbYUsageID),  1.0, -1.0, axisMin, axisMax, DeadZonePercent);
		
		SetupAxis(device, GetAxis(device, controller->_lTriggerUsageID), 0.0,  1.0, 0, 256, 0.0f);
		SetupAxis(device, GetAxis(device, controller->_rTriggerUsageID), 0.0,  1.0, 0, 256, 0.0f);
		
		IOHIDDeviceSetInputValueMatchingMultiple(device, (__bridge CFArrayRef)matches);
		IOHIDDeviceRegisterInputValueCallback(device, ControllerInput, (__bridge void *)controller);
		IOHIDDeviceRegisterRemovalCallback(device, ControllerDisconnected, (void *)CFBridgingRetain(controller));
		IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
		
		[CONTROLLERS addObject:controller];
		[[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidConnectNotification object:controller];
	}
}

static void
ControllerDisconnected(void *context, IOReturn result, void *sender)
{
	if(result == kIOReturnSuccess){
		CCController *controller = CFBridgingRelease((CFTypeRef)context);
		
		NSLog(@"%p, %p, %d", context, sender, result);
		
		[CONTROLLERS removeObject:controller];
		[[NSNotificationCenter defaultCenter] postNotificationName:GCControllerDidDisconnectNotification object:controller];
	}
}

//MARK: Input callbacks

static float
Clamp(float value)
{	
	return MAX(-1.0f, MIN(value, 1.0f));
}

static void
ControllerInput(void *context, IOReturn result, void *sender, IOHIDValueRef value)
{
	@autoreleasepool {
		if(result == kIOReturnSuccess){
			CCController *controller = (__bridge CCController *)context;
			GCExtendedGamepadSnapShotDataV100 *snapshot = &controller->_snapshot;
			
			IOHIDElementRef element = IOHIDValueGetElement(value);
			
			uint32_t usagePage = IOHIDElementGetUsagePage(element);
			uint32_t usage = IOHIDElementGetUsage(element);
			
			CFIndex state = (int)IOHIDValueGetIntegerValue(value);
			float analog = IOHIDValueGetScaledValue(value, kIOHIDValueScaleTypeCalibrated);
			
//			NSLog(@"usagePage: 0x%02X, usage 0x%02X, value: %d / %f", usagePage, usage, state, analog);
			
			if(usagePage == kHIDPage_Button){
					if(usage == controller->_buttonPauseUsageID){if(state) controller.controllerPausedHandler(controller);}
					if(usage == controller->_buttonAUsageID){snapshot->buttonA = state;}
					if(usage == controller->_buttonBUsageID){snapshot->buttonB = state;}
					if(usage == controller->_buttonXUsageID){snapshot->buttonX = state;}
					if(usage == controller->_buttonYUsageID){snapshot->buttonY = state;}
					if(usage == controller->_lShoulderUsageID){snapshot->leftShoulder = state;}
					if(usage == controller->_rShoulderUsageID){snapshot->rightShoulder = state;}
			}
			
			if(usagePage == kHIDPage_GenericDesktop){
				if(usage == controller->_lThumbXUsageID ){snapshot->leftThumbstickX  = analog;}
				if(usage == controller->_lThumbYUsageID ){snapshot->leftThumbstickY  = analog;}
				if(usage == controller->_rThumbXUsageID ){snapshot->rightThumbstickX = analog;}
				if(usage == controller->_rThumbYUsageID ){snapshot->rightThumbstickY = analog;}
				if(usage == controller->_lTriggerUsageID){snapshot->leftTrigger     = analog;}
				if(usage == controller->_rTriggerUsageID){snapshot->rightTrigger    = analog;}
			}
			
			if(controller->_usesHatSwitch){
				if(usagePage == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_Hatswitch){
					switch(state){
						case  0: snapshot->dpadX =  0.0; snapshot->dpadY =  1.0; break;
						case  1: snapshot->dpadX =  1.0; snapshot->dpadY =  1.0; break;
						case  2: snapshot->dpadX =  1.0; snapshot->dpadY =  0.0; break;
						case  3: snapshot->dpadX =  1.0; snapshot->dpadY = -1.0; break;
						case  4: snapshot->dpadX =  0.0; snapshot->dpadY = -1.0; break;
						case  5: snapshot->dpadX = -1.0; snapshot->dpadY = -1.0; break;
						case  6: snapshot->dpadX = -1.0; snapshot->dpadY =  0.0; break;
						case  7: snapshot->dpadX = -1.0; snapshot->dpadY =  1.0; break;
						default: snapshot->dpadX =  0.0; snapshot->dpadY =  0.0; break;
					}
				}
			} else if(usagePage == kHIDPage_Button){
					if(usage == controller->_dpadLUsageID){snapshot->dpadX = Clamp(snapshot->dpadX - (state ? 1.0f : -1.0f));}
					if(usage == controller->_dpadRUsageID){snapshot->dpadX = Clamp(snapshot->dpadX + (state ? 1.0f : -1.0f));}
					if(usage == controller->_dpadDUsageID){snapshot->dpadY = Clamp(snapshot->dpadY - (state ? 1.0f : -1.0f));}
					if(usage == controller->_dpadUUsageID){snapshot->dpadY = Clamp(snapshot->dpadY + (state ? 1.0f : -1.0f));}
			}
			
			controller->_gamepad.snapshotData = NSDataFromGCExtendedGamepadSnapShotDataV100(snapshot);
		}
	}
}

//MARK: Misc

-(GCGamepad *)gamepad
{
	// Not implemented for now.
	return nil;
}

-(GCExtendedGamepad *)extendedGamepad
{
	// TODO should make this weak and lazy.
	// Then we can pump the gamepad data only when it's active.
	return _gamepad;
}

@end

#endif


#if __CC_PLATFORM_IOS || __CC_PLATFORM_MAC

@implementation GCExtendedGamepad(SnapshotDataFast)

-(NSData *)snapshotDataFast
{
	GCExtendedGamepadSnapShotDataV100 snapshot = {
		.version = 0x0100,
		.size = sizeof(GCExtendedGamepadSnapShotDataV100),
		.dpadX = self.dpad.xAxis.value,
		.dpadY = self.dpad.yAxis.value,
		.buttonA = self.buttonA.value,
		.buttonB = self.buttonB.value,
		.buttonX = self.buttonX.value,
		.buttonY = self.buttonY.value,
		.leftShoulder = self.leftShoulder.value,
		.rightShoulder = self.rightShoulder.value,
		.leftThumbstickX = self.leftThumbstick.xAxis.value,
		.leftThumbstickY = self.leftThumbstick.yAxis.value,
		.rightThumbstickX = self.rightThumbstick.xAxis.value,
		.rightThumbstickY = self.rightThumbstick.yAxis.value,
		.leftTrigger = self.leftTrigger.value,
		.rightTrigger = self.rightTrigger.value,
	};
	
	return NSDataFromGCExtendedGamepadSnapShotDataV100(&snapshot);
}

@end

#endif