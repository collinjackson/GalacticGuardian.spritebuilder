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
#import "NebulaBackground.h"
#import "PauseScene.h"
#import "GameController.h"


#if GameControllerSupported
@interface PauseScene()<GameControllerDelegate>
@end
#endif


@implementation PauseScene {
	CCSlider *_musicSlider;
	CCSlider *_soundSlider;
	CCButton *_hardMode;
}

-(void)didLoadFromCCB
{
	self.contentSize = [CCDirector sharedDirector].designSize;
	self.contentSizeType = CCSizeTypePoints;
	
	// Set the button values to the ones stored in the user preferences.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	_musicSlider.sliderValue = [[defaults objectForKey:DefaultsMusicKey] floatValue];
	_soundSlider.sliderValue = [[defaults objectForKey:DefaultsSoundKey] floatValue];
	_hardMode.title = [NSString stringWithFormat:@"Difficulty: %@", [defaults boolForKey:DefaultsDifficultyHardKey] ? @"Hard" : @"Demo"];
}

-(void)dealloc
{
	CCLOG(@"PauseScene dealloc");
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
	[self dismiss:nil];
}
#endif

-(void)musicVolumeChanged:(CCSlider *)slider
{
	[[NSUserDefaults standardUserDefaults] setFloat:slider.sliderValue forKey:DefaultsMusicKey];
	
	[OALSimpleAudio sharedInstance].bgVolume = slider.sliderValue;
}

-(void)soundVolumeChanged:(CCSlider *)slider
{
	[[NSUserDefaults standardUserDefaults] setFloat:slider.sliderValue forKey:DefaultsSoundKey];
	
	[OALSimpleAudio sharedInstance].effectsVolume = slider.sliderValue;
	[[OALSimpleAudio sharedInstance] playEffect:@"TempSounds/Laser.wav" volume:0.25 pitch:1.0 pan:0.0 loop:NO];
}

-(void)toggleDemoMode:(CCButton *)button
{	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	BOOL value = ![defaults boolForKey:DefaultsDifficultyHardKey];
	[defaults setBool:value forKey:DefaultsDifficultyHardKey];
	
	button.title = [NSString stringWithFormat:@"Difficulty: %@", value ? @"Hard" : @"Demo"];
}

-(void)toggleDistortionMode:(CCButton *)button
{
	NSString *mode = [NebulaBackground toggleDistortionMode];
	button.title = [NSString stringWithFormat:@"Distortion: %@", mode];
}

-(void)dismiss:(id)sender
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	CCTransition *fade = [CCTransition transitionCrossFadeWithDuration:0.25];
	[[CCDirector sharedDirector] popSceneWithTransition:fade];
}

-(void)endGame:(id)sender
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[[CCDirector sharedDirector] popScene];
	[[CCDirector sharedDirector] replaceScene:[CCBReader loadAsScene:@"MainMenu"]];
}

@end
