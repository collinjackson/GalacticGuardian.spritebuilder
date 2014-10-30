#import <GameController/GameController.h>

#import "ObjectiveChipmunk/ObjectiveChipmunk.h"

#import "Controls.h"
#import "FancyJoystick.h"


// I replaced my simple joystick class with the much prettier FancyJoystick class.
// I'll leave it here for posterity though.

//@interface VirtualJoystick : CCNode @end
//@implementation VirtualJoystick {
//	CGPoint _center;
//	float _radius;
//	
//	CGPoint _value;
//	
//	__unsafe_unretained CCTouch *_trackingTouch;
//}
//
//-(instancetype)initWithSize:(CGFloat)size
//{
//	if((self = [super init])){
//		self.contentSize = CGSizeMake(size, size);
//		self.anchorPoint = ccp(0.5, 0.5);
//	}
//	
//	return self;
//}
//
//-(void)onEnter
//{
//	[super onEnter];
//	
//	_center = self.position;
//	_radius = self.contentSize.width/2.0;
//	
//	// Quick and dirty way to draw the joystick nub.
//	CCDrawNode *drawNode = [CCDrawNode node];
//	[self addChild:drawNode];
//	
//	[drawNode drawDot:self.anchorPointInPoints radius:_radius color:[CCColor colorWithWhite:1.0 alpha:0.5]];
//	
//	self.userInteractionEnabled = YES;
//}
//
//-(CGPoint)value {return _value;}
//
//-(void)setTouchPosition:(CGPoint)touch
//{
//	CGPoint delta = cpvclamp(cpvsub(touch, _center), _radius);
//	self.position = cpvadd(_center, delta);
//	
//	_value = cpvmult(delta, 1.0/_radius);
//}
//
//-(void)touchBegan:(CCTouch *)touch withEvent:(CCTouchEvent *)event
//{
//	if(_trackingTouch) return;
//	
//	CGPoint pos = [touch locationInNode:self.parent];
//	if(cpvnear(_center, pos, _radius)){
//		_trackingTouch = touch;
//		self.touchPosition = pos;
//	}
//}
//
//-(void)touchMoved:(CCTouch *)touch withEvent:(CCTouchEvent *)event
//{
//	if(touch == _trackingTouch){
//		self.touchPosition = [touch locationInNode:self.parent];
//	}
//}
//
//-(void)touchEnded:(CCTouch *)touch withEvent:(CCTouchEvent *)event
//{
//	if(touch == _trackingTouch){
//		_trackingTouch = nil;
//		self.touchPosition = _center;
//	}
//}
//
//-(void)touchCancelled:(CCTouch *)touch withEvent:(CCTouchEvent *)event
//{
//	[self touchEnded:touch withEvent:event];
//}
//
//@end


@implementation Controls {
	FancyJoystick *_virtualJoystick;
	FancyJoystick *_virtualAimJoystick;
	
	GCController *_controller;
	GCControllerDirectionPad *_controllerStick;
	GCControllerDirectionPad *_controllerAim;
	GCControllerDirectionPad *_controllerDpad;
	
	NSMutableDictionary *_buttonStates;
	NSMutableDictionary *_buttonHandlers;
	
	NSArray *_observers;
}

-(id)init
{
	if((self = [super init])){
		CGSize viewSize = [CCDirector sharedDirector].viewSize;
		self.contentSize = viewSize;
		
		CGFloat joystickOffset = viewSize.width/8.0;
		
		CCNode *rocketButton = [CCBReader loadAsScene:@"RocketButton" owner:self];
		rocketButton.position = ccp(2.0*joystickOffset, joystickOffset);
		rocketButton.contentSize = CGSizeMake(0.1*joystickOffset, 0.1*joystickOffset);
		[self addChild:rocketButton];
		
		_virtualJoystick = [FancyJoystick node];
		_virtualJoystick.scale = 2.0*joystickOffset/_virtualJoystick.contentSize.width;
		_virtualJoystick.position = ccp(joystickOffset, joystickOffset);
		[self addChild:_virtualJoystick];
		
		_virtualAimJoystick = [FancyJoystick node];
		_virtualAimJoystick.scale = 2.0*joystickOffset/_virtualJoystick.contentSize.width;
		_virtualAimJoystick.position = ccp(viewSize.width - joystickOffset, joystickOffset);
		[self addChild:_virtualAimJoystick];
		
		CCButton *pauseButton = [CCButton buttonWithTitle:@"Pause"];
		pauseButton.anchorPoint = ccp(1, 1);
		pauseButton.positionType = CCPositionTypeMake(CCPositionUnitUIPoints, CCPositionUnitUIPoints, CCPositionReferenceCornerTopRight);
		pauseButton.position = ccp(20, 20);
		[self addChild:pauseButton];
		
		__weak typeof(self) _self = self;
		pauseButton.block = ^(id sender){
			[_self callHandler:@(ControlPauseButton) value:YES];
		};
		
		_buttonStates = [NSMutableDictionary dictionary];
		_buttonHandlers = [NSMutableDictionary dictionary];
		
		self.userInteractionEnabled = YES;
		
		[self setupGamepadSupport];
	}
	
	return self;
}

-(void)logController:(GCController *)controller
{
	NSLog(@"Controller: %@", controller);
	NSLog(@"	Extended: %@", controller.extendedGamepad);
	NSLog(@"	VendorName: %@", controller.vendorName);
}

-(BOOL)activateController:(GCController *)controller
{
	if(_controller || controller.gamepad == nil) return NO;
	
	NSLog(@"Using controller %@", controller);
	_controller = controller;
	controller.playerIndex = 0;
	
	_controllerStick = controller.extendedGamepad.leftThumbstick;
	_controllerAim = controller.extendedGamepad.rightThumbstick;
	_controllerDpad = controller.gamepad.dpad;
	
	__weak typeof(self) _self = self;
	
	controller.gamepad.buttonA.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed){
		[_self setButtonValue:ControlFireButton value:pressed];
	};
	
	controller.controllerPausedHandler = ^(GCController *controller){
		[_self callHandler:@(ControlPauseButton) value:YES];
	};
	
	self.visible = NO;
	return YES;
}

-(void)deactivateController:(GCController *)controller
{
	if(controller == _controller){
		_controller.gamepad.buttonA.valueChangedHandler = nil;
		_controller.controllerPausedHandler = nil;
		
		_controller = nil;
		_controllerStick = nil;
		
		self.visible = YES;
	}
}

-(void)setupGamepadSupport
{
	if(NSClassFromString(@"GCController") == nil) return;

	NSArray *controllers = [GCController controllers];
	NSLog(@"%d controllers found.", (int)controllers.count);
	
	for(GCController *controller in controllers){
		[self logController:controller];
		if(_controller == nil) [self activateController:controller];
	}
}

-(void)onEnter
{
	if(NSClassFromString(@"GCController")){
		id connect = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:nil
			usingBlock:^(NSNotification *notification){
				NSLog(@"Controller connected.");
				
				GCController *controller = notification.object;
				[self logController:controller];
				[self activateController:controller];
			}
		];
		
		id disconnect = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:nil
			usingBlock:^(NSNotification *notification){
				NSLog(@"Controller disconnected.");
				
				GCController *controller = notification.object;
				[self logController:controller];
				[self deactivateController:controller];
			}
		];
		
		_observers = @[connect, disconnect];
	}
	
	[super onEnter];
}

-(void)onExit
{
	for(id observer in _observers){
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	}
	
	[super onExit];
}

-(void)dealloc
{
	// TODO memory leak!!!
	// 90% certain it's the CGController blocks.
	NSLog(@"dealloc");
}

-(void)update:(CCTime)delta
{
	CGPoint aim = CGPointZero;
	
	if(_controllerAim){
		aim = CGPointMake(_controllerAim.xAxis.value, _controllerAim.yAxis.value);
	} else {
		aim = _virtualAimJoystick.direction;
	}
	
	[self setButtonValue:ControlFireButton value:(aim.x*aim.x + aim.y*aim.y) > 0.25];
}

-(void)setButtonValue:(ControlButton)button value:(BOOL)value
{
	NSNumber *key = @(button);
	BOOL prev = [_buttonStates[key] boolValue];
	
	if(value != prev){
		_buttonStates[key] = @(value);
		[self callHandler:key value:value];
	}
}

-(void)callHandler:(id)key value:(BOOL)value;
{
	if(self.isRunningInActiveScene){
		ControlHandler handler = _buttonHandlers[key];
		if(handler) handler(value);
	}
}

-(CGPoint)thrustDirection
{
	if(_controller){
		return cpvclamp(cpv(
			_controllerStick.xAxis.value + _controllerDpad.xAxis.value,
			_controllerStick.yAxis.value + _controllerDpad.yAxis.value
		), 1.0);
	} else {
		return _virtualJoystick.direction;
	}
}

-(CGPoint)aimDirection
{
	if(_controller){
		return cpvclamp(cpv(
			_controllerAim.xAxis.value,
			_controllerAim.yAxis.value
		), 1.0);
	} else {
		return _virtualAimJoystick.direction;
	}
}

-(BOOL)getButton:(ControlButton)button
{
	return [_buttonStates[@(button)] boolValue];
}

-(void)setHandler:(ControlHandler)block forButton:(ControlButton)button
{
	_buttonHandlers[@(button)] = block;
}

-(void)fireRocket:(CCButton *)sender
{
	// Kind of a hack since CCButton doesn't support continuous events.
	[self setButtonValue:ControlRocketButton value:YES];
	[self setButtonValue:ControlRocketButton value:NO];
}

@end
