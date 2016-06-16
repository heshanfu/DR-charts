//
//  CircularChart.m
//  dr-charts
//
//  Created by DHIREN THIRANI on 5/22/16.
//  Copyright © 2016 Product. All rights reserved.
//

#import "CircularChart.h"
#import "Constants.h"

@interface CircularChartDataRenderer : NSObject

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSNumber *value;

@end

@interface CircularChart(){
    CGFloat startAngle;
    CGFloat radius;
    CGPoint center;
    
    CGFloat height;
    
    CAShapeLayer *touchedLayer;
    CAShapeLayer *dataShapeLayer;
}

@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic, strong) NSMutableArray *dataArray;
@property (nonatomic, strong) NSMutableArray *legendArray;
@property (nonatomic, strong) NSNumber *totalCount;
@property (nonatomic, strong) LegendView *legendView;
@property (nonatomic, strong) UIView *circularChartView;

@end

@implementation CircularChart

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.dataArray = [[NSMutableArray alloc] init];
        self.legendArray = [[NSMutableArray alloc] init];
        
        self.textFontSize = 12;
        self.textFont = [UIFont systemFontOfSize:self.textFontSize];
        self.textColor = [UIColor blackColor];
        
        self.strokeWidth = 20;

        self.legendViewType = LegendTypeVertical;
        self.showLegend = TRUE;
    }
    return self;
}

- (void)drawPieChart{
    for(int i = 0; i <[self.dataSource numberOfValuesForCircularChart] ; i++){
        CircularChartDataRenderer *data = [[CircularChartDataRenderer alloc] init];
        [data setColor:[self.dataSource colorForValueInCircularChartWithIndex:i]];
        [data setTitle:[self.dataSource titleForValueInCircularChartWithIndex:i]];
        [data setValue:[self.dataSource valueInCircularChartWithIndex:i]];
        
        [self.dataArray addObject:data];
        
        self.totalCount = [NSNumber numberWithFloat:(self.totalCount.floatValue + data.value.floatValue)];
        
        LegendDataRenderer *legendData = [[LegendDataRenderer alloc] init];
        [legendData setLegendText:data.title];
        [legendData setLegendColor:data.color];
        [self.legendArray addObject:legendData];
    }
    
    self.strokeWidth = [self.dataSource strokeWidthForCircularChart];
    
    height = HEIGHT(self) - 2*INNER_PADDING;
    
    if (self.showLegend) {
        height = HEIGHT(self) - [LegendView getLegendHeightWithLegendArray:self.legendArray legendType:self.legendViewType withFont:self.textFont width:WIDTH(self) - 2*SIDE_PADDING] - 2*INNER_PADDING;
    }
    
    radius = (WIDTH(self) - 2*INNER_PADDING)/2 - self.strokeWidth;

    if (radius > (height - 2*INNER_PADDING - self.strokeWidth)/2) {
        radius = (height - 2*INNER_PADDING - self.strokeWidth)/2;
    }
    
    self.circularChartView = [[UIView alloc] initWithFrame:CGRectMake(0, INNER_PADDING, WIDTH(self), height)];
    
    center = self.circularChartView.center;
    startAngle = 0;
    
    for (CircularChartDataRenderer *data in self.dataArray) {
        [self drawPathWithValue:data.value.floatValue color:data.color];
    }
    
    [self addSubview:self.circularChartView];
    
    if (self.showLegend) {
        [self createLegend];
    }
    
    [self setNeedsDisplay];
}

- (void)drawPathWithValue:(CGFloat)value color:(UIColor *)color{
    CAShapeLayer *shapeLayer = [[CAShapeLayer alloc] init];
    [shapeLayer setPath:[[self drawArcWithValue:value] CGPath]];
    [shapeLayer setStrokeColor:color.CGColor];
    [shapeLayer setFillColor:[[UIColor clearColor] CGColor]];
    [shapeLayer setLineCap:kCALineCapButt];
    [shapeLayer setLineWidth:self.strokeWidth];
    [shapeLayer setValue:[NSString stringWithFormat:@"%0.2f",value] forKey:@"data"];
    
    [CATransaction begin];
    
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    [pathAnimation setFromValue:[NSNumber numberWithFloat:0.0f]];
    [pathAnimation setToValue:[NSNumber numberWithFloat:1.0f]];
    
    CAAnimationGroup *group = [[CAAnimationGroup alloc] init];
    [group setAnimations:[NSArray arrayWithObjects:pathAnimation, nil]];
    [group setDuration:ANIMATION_DURATION];
    [group setFillMode:kCAFillModeBoth];
    [group setRemovedOnCompletion:FALSE];
    [group setBeginTime:CACurrentMediaTime()];
    [group setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut]];
    
    [shapeLayer addAnimation:group forKey:@"animate"];
    
    [CATransaction commit];
    
    [self.circularChartView.layer addSublayer:shapeLayer];
}

- (UIBezierPath *)drawArcWithValue:(CGFloat)value{
    CGFloat endAngle = startAngle + ((value/self.totalCount.floatValue)*360);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path addArcWithCenter:center radius:radius startAngle:DEG2RAD(startAngle) endAngle:DEG2RAD(endAngle) clockwise:YES];
    
    startAngle = endAngle;
    return path;
}

#pragma mark Touch On Chart
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    CGPoint touchPoint = [[touches anyObject] locationInView:self.circularChartView];
    
    if(CGRectContainsPoint(self.circularChartView.frame, touchPoint)){
        CALayer *layer = [self.circularChartView.layer hitTest:touchPoint];
        for(CAShapeLayer *shapeLayer in layer.sublayers){
            if (CGPathContainsPoint(shapeLayer.path, 0, touchPoint, YES)) {
                [shapeLayer setShadowRadius:10.0f];
                [shapeLayer setShadowColor:[[UIColor blackColor] CGColor]];
                [shapeLayer setShadowOpacity:1.0f];
                
                touchedLayer = shapeLayer;

                NSString *data = [shapeLayer valueForKey:@"data"];
                NSString *dataPercentage = [NSString stringWithFormat:@"%0.2f%%",(data.floatValue/self.totalCount.floatValue)*100];
                [self showMarkerWithData:dataPercentage];
                if ([self.delegate respondsToSelector:@selector(didTapOnCircularChartWithValue:)]) {
                    [self.delegate didTapOnCircularChartWithValue:data];
                }
                
                break;
            }
        }
    }
}

- (void)showMarkerWithData:(NSString *)text{
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(self.circularChartView.center.x - 100/2, self.circularChartView.center.y, 100, 2*INNER_PADDING) cornerRadius:3];
    [path closePath];
    [path stroke];
    
    dataShapeLayer = [[CAShapeLayer alloc] init];
    [dataShapeLayer setPath:[path CGPath]];
    [dataShapeLayer setBackgroundColor:[[UIColor whiteColor] CGColor]];
    [dataShapeLayer setFillColor:[[UIColor whiteColor] CGColor]];
    [dataShapeLayer setStrokeColor:[[UIColor whiteColor] CGColor]];
    [dataShapeLayer setLineWidth:3.0F];
    [dataShapeLayer setShadowRadius:5.0f];
    [dataShapeLayer setShadowColor:[[UIColor blackColor] CGColor]];
    [dataShapeLayer setShadowOpacity:1.0f];
    
    CATextLayer *textLayer = [[CATextLayer alloc] init];
    [textLayer setFont:CFBridgingRetain(self.textFont.fontName)];
    [textLayer setFontSize:self.textFontSize];
    [textLayer setFrame:CGPathGetBoundingBox(dataShapeLayer.path)];
    [textLayer setString:[NSString stringWithFormat:@"%@",text]];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    [textLayer setBackgroundColor:[[UIColor clearColor] CGColor]];
    [textLayer setForegroundColor:[self.textColor CGColor]];
    [textLayer setShouldRasterize:YES];
    [textLayer setRasterizationScale:[[UIScreen mainScreen] scale]];
    [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
    [dataShapeLayer addSublayer:textLayer];
    
    [self.circularChartView.layer addSublayer:dataShapeLayer];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [touchedLayer setShadowRadius:0.0f];
    [touchedLayer setShadowColor:[[UIColor clearColor] CGColor]];
    [touchedLayer setShadowOpacity:0.0f];
    
    [dataShapeLayer removeFromSuperlayer];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    [touchedLayer setOpacity:0.7f];
    [touchedLayer setShadowRadius:0.0f];
    [touchedLayer setShadowColor:[[UIColor clearColor] CGColor]];
    [touchedLayer setShadowOpacity:0.0f];
    
    [dataShapeLayer removeFromSuperlayer];
}

- (void) createLegend{
    self.legendView = [[LegendView alloc] initWithFrame:CGRectMake(SIDE_PADDING, BOTTOM(self.circularChartView), WIDTH(self) - 2*SIDE_PADDING, 0)];
    [self.legendView setLegendArray:self.legendArray];
    [self.legendView setFont:self.textFont];
    [self.legendView setTextColor:self.textColor];
    [self.legendView setLegendViewType:self.legendViewType];
    [self.legendView createLegend];
    [self addSubview:self.legendView];
}

@end

@implementation CircularChartDataRenderer

- (instancetype)init{
    self = [super init];
    if (self) {
        self.value = @0;
        self.title = @"";
        self.color = [UIColor blackColor];
    }
    return self;
}


@end