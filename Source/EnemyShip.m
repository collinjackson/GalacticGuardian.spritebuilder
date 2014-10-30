//  Created by Andy Korth on 10/27/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "OALSimpleAudio.h"

#import "Constants.h"

#import "EnemyShip.h"

// To access some of Chipmunk's handy vector functions like cpvlerpconst().
#import "ObjectiveChipmunk/ObjectiveChipmunk.h"

// TODO
#import "CCPhysics+ObjectiveChipmunk.h"

@implementation EnemyShip
{
	CCNode *_mainThruster;
	
	float _speed;
	float _accelTime;
	int _hp;
}

-(void)onEnter
{
	CCPhysicsBody *body = self.physicsBody;
	
	_hp = 5;
	_speed = 25;
	
	// This is used to pick which collision delegate method to call, see GameScene.m for more info.
	body.collisionType = @"enemy";
	
	// This sets up simple collision rules.
	// First you list the categories (strings) that the object belongs to.
	body.collisionCategories = @[CollisionCategoryEnemy];
	// Then you list which categories its allowed to collide with.
	body.collisionMask = @[
		CollisionCategoryPlayer,
		CollisionCategoryDebris,
		CollisionCategoryBullet,
		CollisionCategoryEnemy
	];
	
	// Make the thruster pulse
	float scaleX = _mainThruster.scaleX;
	float scaleY = _mainThruster.scaleY;
	[_mainThruster runAction:[CCActionRepeatForever actionWithAction:[CCActionSequence actions:
						[CCActionScaleTo actionWithDuration:0.1 scaleX:scaleX scaleY:0.5*scaleY],
						[CCActionScaleTo actionWithDuration:0.05 scaleX:scaleX scaleY:scaleY],
						nil
						]]];
	
	[super onEnter];
}

// This method is called from [GameScene fixedUpdate:], not from Cocos2D.
-(void)ggFixedUpdate:(CCTime)delta scene:(GameScene *)scene
{
	if(_hp == 0 || [scene.player isDead]) return;
	
	CCPhysicsBody *body = self.physicsBody;
	
	CGPoint targetVelocity = ccpMult(ccpNormalize(ccpSub(scene.playerPosition, self.position)), _speed);
	
	CGPoint velocity = cpvlerpconst(body.velocity, targetVelocity, _speed/_accelTime*delta);
	
	//	CCLOG(@"velocity: %@", NSStringFromCGPoint(velocity));
	
	body.velocity = velocity;
	if(cpvlengthsq(velocity)){
		self.rotation = -CC_RADIANS_TO_DEGREES(atan2f(velocity.y, velocity.x));
		_mainThruster.visible = YES;
	} else {
		_mainThruster.visible = NO;
	}
}

-(BOOL) takeDamage
{
	_hp -= 1;
	return _hp <= 0;
}



@end