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

#import "CCPhysics+ObjectiveChipmunk.h"

#import "Constants.h"
#import "GameScene.h"
#import "Rocket.h"
#import "EnemyShip.h"
#import "CCEffectLine.h"
#import "CCEffectLineFactory.h"


static const float RocketAcceleration = 10.0;

static const float RocketDamage[] = {0.0, 14.0, 20.0, 10.0};
static const float RocketSplash = 150.0;

static const int RocketClusters = 3;
static const CCTime RocketClusterInterval = 0.2;
static const float RocketClusterRange = 25.0;


@implementation Rocket {
	RocketLevel _level;
	EnemyShip *_target;
	__weak CCSprite *_lockSprite;
    BOOL _trailStarted;
}

+(CCSprite *)lockSprite
{
	CCSprite *sprite = [CCSprite spriteWithImageNamed:@"Sprites/targetLock.png"];
	[sprite runAction:[CCActionRepeatForever actionWithAction:[CCActionRotateBy actionWithDuration:1.0 angle:360.0]]];
	
	return sprite;
}

+(NSDictionary*) trailSetup
{
    return @{
      // basic setups
      @"name"               : @"Bullet Tracer",
      @"image"              : @"effects.png",
      @"lineMode"           : @(CCEffectLineModePointToPoint),
      @"widthMode"          : @(CCEffectLineWidthBarrel),
      @"widthStart"         : @(1.0),
      @"widthEnd"           : @(10.0),
      // textures used
      @"textureCount"       : @(8),
      @"textureIndex"       : @(0),
      @"textureList"        : @[@(0), @(1)],
      @"textureMix"         : @(CCEffectLineTextureBlendLinear),
      @"textureAnimation"   : @(CCEffectLineAnimationScroll),
      @"textureScroll"      : @(0.00f),
      @"textureMixTime"     : @(0.50f),
      @"textureScale"       : @(0.50),
      // texture mixing
      @"life"               : @(3.00f),
      @"autoRemove"         : @(YES),
      @"smooth"             : @(YES),
      @"speedMultiplyer"    : @(1.00f),
      @"granularity"        : @(1.0f),
      @"drawLineStart"      : @(YES),
      @"drawLineEnd"        : @(YES),
      @"wind"               : @"{0, 0}",
      @"gravity"            : @"{0, 0}",
      @"colorStart"         : @"{1.0, 1.0, 1.0, 1.0}",
      @"colorEnd"           : @"{0.5, 0.5, 0.5, 0.0}",
      };
}

+(instancetype)rocketWithLevel:(RocketLevel)level target:(EnemyShip *)target
{
	NSAssert(level != RocketNone, @"Not a valid rocket level.");
	
	Rocket *rocket = (Rocket *)[CCBReader load:@"Rocket"];
	rocket->_level = level;
	
	[rocket setTarget:target];
	
	CGSize size = rocket.contentSize;
	CGFloat radius = size.height/2.0;
	
	CCPhysicsBody *body = rocket.physicsBody = [CCPhysicsBody bodyWithPillFrom:ccp(radius, radius) to:ccp(size.width - radius, radius) cornerRadius:radius];
	body.collisionType = @"rocket";
	body.collisionCategories = @[CollisionCategoryBullet];
	body.collisionMask = @[CollisionCategoryEnemy, CollisionCategoryAsteroid];
    
    // Setup trail effect
    NSDictionary* trailSettings = [[[CCEffectLineFactory alloc] init] lineFromName:@"Bullet Tracer"];
    rocket.trail = [CCEffectLine lineWithDictionary:[self trailSetup]];
    //rocket.trail.blendMode = [CCBlendMode addMode];
	
	[rocket scheduleBlock:^(CCTimer *timer) {
		[rocket destroy];
	} delay:1.0];
	
	return rocket;
}

-(void)setTarget:(EnemyShip *)target
{
	_target = target;
	
	[_lockSprite removeFromParent];
	
	CCSprite *lockSprite = [Rocket lockSprite];
	_lockSprite = lockSprite;
	[target addChild:lockSprite z:Z_RETICLE];
}

-(void)fixedUpdate:(CCTime)delta
{
	CCPhysicsBody *body = self.physicsBody;
	
	if(_target.hp <= 0){
		CGPoint aim = ccpAdd(body.absolutePosition, ccpMult(body.velocity, 1.0));
		_target = [(GameScene *)self.scene rocketTarget:aim limit:INFINITY];
	}
	
	CGPoint direction = (_target ? ccpSub(_target.position, body.absolutePosition) : body.velocity);
	
	const float accelTime = 0.5;
	const float speed = 200.0;

	CGPoint desiredVelocity = ccpMult(ccpNormalize(direction), speed);
	CGPoint velocity = cpvlerpconst(body.velocity, desiredVelocity, speed/accelTime*delta);
	
	body.velocity = velocity;
	if(cpvlengthsq(velocity) > 0.0){
		self.rotation = -CC_RADIANS_TO_DEGREES(ccpToAngle(velocity));
	}
    
    // Add points to trail
    if (_trailStarted)
    {
        [_trail add:self.position timestamp:[NSDate timeIntervalSinceReferenceDate]];
    }
    else
    {
        [_trail start:self.position timestamp:[NSDate timeIntervalSinceReferenceDate]];
        _trailStarted = YES;
    }
}

// Apply splash damage.
-(void)splashAt:(CGPoint)pos parent:(CCNode *)parent
{
	GameScene *scene = (GameScene *)parent.scene;
	[scene splashDamageAt:pos radius:RocketSplash damage:RocketDamage[_level]];
	
	[[OALSimpleAudio sharedInstance] playEffect:@"TempSounds/Explosion.wav" volume:2.0 pitch:scene.pitchScale pan:0.0 loop:NO];
}

-(void)destroy
{
	CCNode *parent = self.parent;
	CGPoint pos = self.position;
	
	[self splashAt:pos parent:parent];
	
	if(_level == RocketCluster){
		for(int i=1; i<RocketClusters; i++){
			[parent scheduleBlock:^(CCTimer *timer) {
				CGPoint splashPos = ccpAdd(pos, ccpMult(CCRANDOM_ON_UNIT_CIRCLE(), RocketClusterRange));
				[self splashAt:splashPos parent:parent];
			} delay:i*RocketClusterInterval];
		}
	}
	
	[(GameScene *)parent.scene drawGlow:pos scale:3.0];
	
	[_lockSprite removeFromParent];
	[self removeFromParent];
    [_trail end:self.position timestamp:[NSDate timeIntervalSinceReferenceDate]];
}

@end
