/*
 * Galactic Guardian
 *
 * Copyright (c) 2015 Scott Lembcke and Andy Korth
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

#import "Constants.h"

#import "MainMenu.h"
#import "NebulaBackground.h"
#import "GameScene.h"
#import "ShipSelectionScene.h"
#import "PauseScene.h"
#import "GameController.h"


#if GameControllerSupported
@interface MainMenu()<GameControllerDelegate> {
	GCExtendedGamepadSnapshot *_gamepad;
}

@end
#endif


@implementation MainMenu {
	NebulaBackground *_background;
	CCTime _time;
	
	CCLabelTTF* _titleLabel;
	CCButton *_playButton;
	
	CCSprite* _ship1;
	CCSprite* _ship2;
	CCSprite* _ship3;
	
	CCParticleSystem *_particles;
}

+(void)initialize
{
	if(self != [MainMenu class]) return;
	
	// This doesn't really belong here, but there isn't a great platform common "just launched" location.
	[CCDirector sharedDirector].fixedUpdateInterval = 1.0/120.0;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:@{
		DefaultsMusicKey: @(1.0),
		DefaultsSoundKey: @(1.0),
	}];
	
	[OALSimpleAudio sharedInstance].bgVolume = [defaults floatForKey:DefaultsMusicKey];
	[OALSimpleAudio sharedInstance].effectsVolume = [defaults floatForKey:DefaultsSoundKey];
	
	[[OALSimpleAudio sharedInstance] playBg:@"GalacticGuardian.m4a" loop:YES];
}

-(void)didLoadFromCCB
{
	_particles = (CCParticleSystem *)[CCBReader load:@"DistortionParticles/Menu"];
	_particles.shader = [CCShader shaderNamed:@"DistortionParticle"];
	_particles.positionType = CCPositionTypeNormalized;
	_particles.position = _titleLabel.position;
	_particles.posVar = ccp(_titleLabel.contentSize.width / 2.0f, 15.0f);
	[_background.distortionNode addChild:_particles];
	
	// Make the "no physics node" warning go away.
	_ship1.physicsBody = nil;
	_ship2.physicsBody = nil;
	_ship3.physicsBody = nil;
	
	// Arbitrary positive number to avoid layering issues with the ships.
	_playButton.zOrder = 100;
	
	// Force an update early to run the positioning code before the transition runs
	[self update:0.0];
}

-(void)dealloc
{
	CCLOG(@"MainMenu dealloc");
}

#if GameControllerSupported
-(void)onEnterTransitionDidFinish
{
	[super onEnterTransitionDidFinish];
	
	[GameController addDelegate:self];
}

-(void)onExitTransitionDidStart
{
	[super onExitTransitionDidStart];
	
	[GameController removeDelegate:self];
}

-(void)pausePressed:(NSUInteger)index
{
	[self showOptionsMenu];
}

-(void)snapshotDidChange:(NSData *)snapshotData index:(NSUInteger)index
{
	_gamepad.snapshotData = snapshotData;
}

-(void)controllerDidConnect:(NSUInteger)index
{
	_gamepad = [[GCExtendedGamepadSnapshot alloc] init];
	_gamepad.buttonA.valueChangedHandler = ^(GCControllerButtonInput *button, float value, BOOL pressed){
		if(pressed && _playButton.enabled) [self showShipSelector];
	};
}

-(void)controllerDidDisconnect:(NSUInteger)index
{
	_gamepad = nil;
}
#endif

-(void)update:(CCTime)delta
{
	_time += delta;
	
	// There is a simple hack in the vertex shader to make the nebula scroll.
	_background.shaderUniforms[@"u_ScrollOffset"] = [NSValue valueWithCGPoint:ccp(0.0f, fmod(_time/4.0, 1.0))];
	
	// Set up three ships moving around just for fun.
	[self setShip:_ship1 atTime:_time atOffset:0.0f];
	[self setShip:_ship2 atTime:_time  atOffset:1.0f];
	[self setShip:_ship3 atTime:_time  atOffset:-1.0f];
}

-(void) setShip:(CCSprite *) ship atTime:(CCTime) t atOffset:(float) offset
{
	float phase = (offset * M_PI * 2.0f / 3.0f);
	
	// Nice periodic motion left and right
	float xPos = sinf(t + phase);
	// Since the derivative of sin is cos, this gives us the direction of the ship.
	float shipRotation = 15.0*cosf(t + phase);
	
	// Add a little scaling synced with the  for a nice fake 3D effect.
	float fakeDistance = 7.0;
	float depth = cosf(t + phase);
	float scale = (fakeDistance + depth)/fakeDistance;
	
	CGSize size = self.contentSizeInPoints;
	float yOffset = 0.25*size.height + sinf(t / 3.0f + phase) * 40.0f;
	
	// They rotate +/- 15 degrees.
	// We are modifying the parent node so we can animate the ship independently for the fly-away animation.
	ship.parent.rotation = shipRotation;
	ship.parent.position = ccp(xPos * 90.0f + offset * 20.0f + 0.5*size.width, yOffset);
	ship.parent.scale = scale;
	
	// Fiddle with the zOrder for layering effects.
	NSInteger buttonZ = _playButton.zOrder;
	ship.parent.zOrder = (depth < 0.0 ? buttonZ - 1: buttonZ + 1);
}


-(void)showOptionsMenu
{
	CCDirector *director = [CCDirector sharedDirector];
	CGSize viewSize = director.viewSize;
	
	PauseScene *pause = (PauseScene *)[CCBReader load:@"PauseScene"];
	// if you get in there from this way, don't show the button.
	[pause.menuButton removeFromParent];
	
	CCRenderTexture *rt = [CCRenderTexture renderTextureWithWidth:viewSize.width height:viewSize.height];
	
	GLKMatrix4 projection = director.projectionMatrix;
	CCRenderer *renderer = [rt begin];
	[self visit:renderer parentTransform:&projection];
	[rt end];
	
	CCSprite *screenGrab = [CCSprite spriteWithTexture:rt.texture];
	screenGrab.anchorPoint = ccp(0.0, 0.0);
	screenGrab.effect = [CCEffectStack effects:
#if !CC_DIRECTOR_IOS_THREADED_RENDERING
		// BUG!
		[CCEffectBlur effectWithBlurRadius:4.0],
#endif
		[CCEffectSaturation effectWithSaturation:-0.5],
		nil
	];
	
	[pause addChild:screenGrab z:-1];
	
	[director pushScene:pause withTransition:[CCTransition transitionCrossFadeWithDuration:0.25]];
}


-(void)showShipSelector
{
	// Remove label so it doesn't show through the background and so it makes a good cinematic when we select a ship.
	[_titleLabel removeFromParent];
	[_particles removeFromParent];
	_playButton.enabled = NO;
	
	CCDirector *director = [CCDirector sharedDirector];
	CGSize viewSize = director.viewSize;
	
	ShipSelectionScene *newScene = (ShipSelectionScene *)[CCBReader load:@"ShipSelectionScene"];
	newScene.mainMenu = self;
	
	CCRenderTexture *rt = [CCRenderTexture renderTextureWithWidth:viewSize.width height:viewSize.height];
	
	GLKMatrix4 projection = director.projectionMatrix;
	CCRenderer *renderer = [rt begin];
	[self visit:renderer parentTransform:&projection];
	[rt end];
	
	CCSprite *screenGrab = [CCSprite spriteWithTexture:rt.texture];
	screenGrab.anchorPoint = ccp(0.0, 0.0);
	screenGrab.effect = [CCEffectStack effects:
#if !CC_DIRECTOR_IOS_THREADED_RENDERING
			// BUG!
			[CCEffectBlur effectWithBlurRadius:4.0],
#endif
		[CCEffectSaturation effectWithSaturation:-0.5],
		nil
	];
	
	[newScene addChild:screenGrab z:-1];
	
	[director pushScene:newScene withTransition:[CCTransition transitionCrossFadeWithDuration:0.25]];
}


-(void) launchWithShip:(ShipType) shipType;
{
	[self scheduleBlock:^(CCTimer *timer) {
		GameScene *scene = [[GameScene alloc] initWithShipType:shipType];
		[[CCDirector sharedDirector] replaceScene:scene];
	}delay:2.75f];

	CCSprite *ship = @[_ship3, _ship2, _ship1][shipType];
	[ship runAction:[CCActionMoveBy actionWithDuration:2.5f position:ccp(0.0f, 400.0f)] ];
	[ship runAction:[CCActionScaleTo actionWithDuration:2.5f scale:2.5f]];
}

@end
