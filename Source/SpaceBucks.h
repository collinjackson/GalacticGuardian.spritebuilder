#import "CCSprite.h"
#import "Constants.h"
#import "PlayerShip.h"
#import "GameScene.h"


typedef NS_ENUM(NSUInteger, SpaceBuckType){
	SpaceBuck_1, SpaceBuck_4, SpaceBuck_8
};


@interface SpaceBucks : CCSprite

@property(nonatomic, assign) float accelRange;
@property(nonatomic, assign) float accelAmount;

@property(nonatomic, assign) int amount;

-(instancetype)initWithAmount:(SpaceBuckType) type;
-(void)ggFixedUpdate:(CCTime)delta scene:(GameScene *)scene;

@end
