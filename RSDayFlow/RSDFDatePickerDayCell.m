//
// RSDFDatePickerDayCell.m
//
// Copyright (c) 2013 Evadne Wu, http://radi.ws/
// Copyright (c) 2013-2016 Ruslan Skorb, http://ruslanskorb.com
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSDFDatePickerDayCell.h"

CGFloat roundOnBase(CGFloat x, CGFloat base) {
    return round(x * base) / base;
}

@interface RSDFDatePickerDayCell ()

+ (NSCache *)imageCache;
+ (id)fetchObjectForKey:(id)key withCreator:(id(^)(void))block;

@property (nonatomic, readonly, strong) UIImageView *selectedDayImageView;
@property (nonatomic, readonly, strong) UIImageView *overlayImageView;
@property (nonatomic, readonly, strong) UIImageView *markImageView;

@end

@implementation RSDFDatePickerDayCell

@synthesize dateLabel = _dateLabel;
@synthesize selectedDayImageView = _selectedDayImageView;
@synthesize overlayImageView = _overlayImageView;
@synthesize markImage = _markImage;
@synthesize markImageColor = _markImageColor;
@synthesize markImageView = _markImageView;

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInitializer];
    }
    return self;
}

- (void)commonInitializer
{
    self.backgroundColor = [self selfBackgroundColor];
	self.enabled = YES;

    [self addSubview:self.selectedDayImageView];
    [self addSubview:self.overlayImageView];
    [self addSubview:self.markImageView];
    [self addSubview:self.dateLabel];

    [self updateSubviews];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.dateLabel.frame = [self selectedImageViewFrame];
    self.selectedDayImageView.frame = [self selectedImageViewFrame];
    self.overlayImageView.frame = [self selectedImageViewFrame];
    self.markImageView.frame = [self markImageViewFrame];
}

- (void)drawRect:(CGRect)rect
{
    [self updateSubviews];
}

- (void)prepareForReuse {
	[super prepareForReuse];

	self.enabled = YES;
}

#pragma mark - Custom Accessors

- (UILabel *)dateLabel
{
    if (!_dateLabel) {
        _dateLabel = [[UILabel alloc] initWithFrame:[self selectedImageViewFrame]];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _dateLabel;
}

- (CGRect)markImageViewFrame
{
    return CGRectMake(roundOnBase(CGRectGetWidth(self.frame) / 2 - 4.5f, [UIScreen mainScreen].scale), roundOnBase(45.5f, [UIScreen mainScreen].scale), 9.0f, 9.0f);
}

- (UIImage *)markImage
{
    if (!_markImage) {
        NSString *markImageKey = [NSString stringWithFormat:@"img_mark_%@", [self.markImageColor description]];
        _markImage = [self ellipseImageWithKey:markImageKey frame:self.markImageView.frame color:self.markImageColor];
    }
    return _markImage;
}

- (UIColor *)markImageColor
{
    if (!_markImageColor) {
        _markImageColor = [UIColor colorWithRed:184/255.0f green:184/255.0f blue:184/255.0f alpha:1.0f];
    }
    return _markImageColor;
}

- (UIImageView *)markImageView
{
    if (!_markImageView) {
        _markImageView = [[UIImageView alloc] initWithFrame:[self markImageViewFrame]];
        _markImageView.backgroundColor = [UIColor clearColor];
        _markImageView.contentMode = UIViewContentModeCenter;
        _markImageView.image = self.markImage;
    }
    return _markImageView;
}

- (UIImageView *)overlayImageView
{
    if (!_overlayImageView) {
        _overlayImageView = [[UIImageView alloc] initWithFrame:[self selectedImageViewFrame]];
        _overlayImageView.backgroundColor = [UIColor clearColor];
        _overlayImageView.opaque = NO;
        _overlayImageView.alpha = 0.5f;
        _overlayImageView.contentMode = UIViewContentModeCenter;
        _overlayImageView.image = [self overlayImage];
    }
    return _overlayImageView;
}

- (UIImageView *)selectedDayImageView
{
    if (!_selectedDayImageView) {
        _selectedDayImageView = [[UIImageView alloc] initWithFrame:[self selectedImageViewFrame]];
        _selectedDayImageView.backgroundColor = [UIColor clearColor];
        _selectedDayImageView.contentMode = UIViewContentModeCenter;
        _selectedDayImageView.image = [self selectedDayImage];
    }
    return _selectedDayImageView;
}

- (CGRect)selectedImageViewFrame
{
	return self.bounds;
}

- (void)setMarkImage:(UIImage *)markImage
{
    if (![_markImage isEqual:markImage]) {
        _markImage = markImage;

        [self setNeedsDisplay];
    }
}

- (void)setMarkImageColor:(UIColor *)markImageColor
{
    if (![_markImageColor isEqual:markImageColor]) {
        _markImageColor = markImageColor;
        _markImage = nil;

        [self setNeedsDisplay];
    }
}

#pragma mark - Private

- (void)updateSubviews
{
	self.layer.borderWidth = 0.0;
	self.layer.borderColor = [UIColor colorWithRed:239/255.0 green:239/255.0 blue:244/255.0 alpha:1].CGColor;

    self.selectedDayImageView.hidden = !self.isSelected || self.isNotThisMonth || self.isOutOfRange;
    self.overlayImageView.hidden = !self.isHighlighted || self.isNotThisMonth || self.isOutOfRange;
    self.markImageView.hidden = !self.isMarked || self.isNotThisMonth || self.isOutOfRange;
	self.dateLabel.backgroundColor = [UIColor clearColor];

    if (self.isNotThisMonth) {
        self.dateLabel.textColor = [self notThisMonthLabelTextColor];
        self.dateLabel.font = [self dayLabelFont];
    } else {
        if (self.isOutOfRange || !self.isEnabled) {
            self.dateLabel.textColor = [self outOfRangeDayLabelTextColor];
			self.dateLabel.backgroundColor = [UIColor colorWithRed:246/255.0 green:246/255.0 blue:246/255.0 alpha:1];
            self.dateLabel.font = [self outOfRangeDayLabelFont];
        } else {
            if (self.isSelected) {
				if (self.isToday) {
					self.layer.borderWidth = 1.0;
					self.dateLabel.font = [self selectedTodayLabelFont];
					self.dateLabel.textColor = [self selectedTodayLabelTextColor];
					self.selectedDayImageView.image = [self selectedTodayImage];
				} else {
					self.dateLabel.font = [self selectedDayLabelFont];
					self.dateLabel.textColor = [self selectedDayLabelTextColor];
					self.selectedDayImageView.image = [self selectedDayImage];
				}
            } else {
				if (self.isToday) {
					self.layer.borderWidth = 1.0;
					self.dateLabel.font = [self todayLabelFont];
					self.dateLabel.textColor = [self todayLabelTextColor];
					self.selectedDayImageView.image = [self selectedTodayImage];
				} else {
					self.dateLabel.font = [self dayLabelFont];
					if (self.dayOff) {
						if (self.isPastDate) {
							self.dateLabel.textColor = [self pastDayOffLabelTextColor];
						} else {
							self.dateLabel.textColor = [self dayOffLabelTextColor];
						}
					} else {
						if (self.isPastDate) {
							self.dateLabel.textColor = [self pastDayLabelTextColor];
						} else {
							self.dateLabel.textColor = [self dayLabelTextColor];
						}
					}
				}
            }

            if (self.marked) {
                self.markImageView.image = self.markImage;
            } else {
                self.markImageView.image = nil;
            }
        }
    }

}

+ (NSCache *)imageCache
{
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
    });
    return cache;
}

+ (id)fetchObjectForKey:(id)key withCreator:(id(^)(void))block
{
    id answer = [[self imageCache] objectForKey:key];
    if (!answer) {
        answer = block();
        [[self imageCache] setObject:answer forKey:key];
    }
    return answer;
}

- (UIImage *)ellipseImageWithKey:(NSString *)key frame:(CGRect)frame color:(UIColor *)color
{
    UIImage *ellipseImage = [[self class] fetchObjectForKey:key withCreator:^id{
        UIGraphicsBeginImageContextWithOptions(frame.size, NO, self.window.screen.scale);
        CGContextRef context = UIGraphicsGetCurrentContext();

        CGRect rect = frame;
        rect.origin = CGPointZero;

        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillEllipseInRect(context, rect);

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return image;
    }];
    return ellipseImage;
}

- (UIImage *)rectImageWithKey:(NSString *)key frame:(CGRect)frame color:(UIColor *)color
{
    UIImage *rectImage = [[self class] fetchObjectForKey:key withCreator:^id{
        UIGraphicsBeginImageContextWithOptions(frame.size, NO, self.window.screen.scale);
        CGContextRef context = UIGraphicsGetCurrentContext();

        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillRect(context, frame);

        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return image;
    }];
    return rectImage;
}

#pragma mark - Atrributes of the View

- (UIColor *)selfBackgroundColor
{
    return [UIColor clearColor];
}

#pragma mark - Attributes of Subviews

- (UIFont *)dayLabelFont
{
    return [UIFont fontWithName:@"SFUIText-Regular" size:17.0f];
}

- (UIColor *)dayLabelTextColor
{
    return [UIColor blackColor];
}

- (UIColor *)dayOffLabelTextColor
{
    return [UIColor colorWithRed:184/255.0f green:184/255.0f blue:184/255.0f alpha:1.0f];
}

- (UIColor *)outOfRangeDayLabelTextColor
{
	return [UIColor colorWithRed:164/255.0 green:170/255.0 blue:179/255.0 alpha:1];
}

- (UIFont *)outOfRangeDayLabelFont
{
    return [UIFont fontWithName:@"SFUIText-Regular" size:17.0f];
}

- (UIColor *)notThisMonthLabelTextColor
{
    return [UIColor clearColor];
}

- (UIColor *)pastDayLabelTextColor
{
    return [self dayLabelTextColor];
}

- (UIColor *)pastDayOffLabelTextColor
{
    return [self dayOffLabelTextColor];
}

- (UIFont *)todayLabelFont
{
    return [UIFont fontWithName:@"SFUIText-Regular" size:17.0f];
}

- (UIColor *)todayLabelTextColor
{
    return [UIColor colorWithRed:0/255.0f green:121/255.0f blue:255/255.0f alpha:1.0f];
}

- (UIFont *)selectedTodayLabelFont
{
    return [UIFont fontWithName:@"SFUIText-Regular" size:17.0f];
}

- (UIColor *)selectedTodayLabelTextColor
{
    return [UIColor whiteColor];
}

- (UIColor *)selectedTodayImageColor
{
    return [UIColor colorWithRed:0/255.0f green:121/255.0f blue:255/255.0f alpha:1.0f];
}

- (UIImage *)customSelectedTodayImage
{
    return nil;
}

- (UIImage *)selectedTodayImage
{
    UIImage *selectedTodayImage = [self customSelectedTodayImage];
    if (!selectedTodayImage) {
        UIColor *selectedTodayImageColor = [self selectedTodayImageColor];
        NSString *selectedTodayImageKey = [NSString stringWithFormat:@"img_selected_today_%@", [selectedTodayImageColor description]];
        selectedTodayImage = [self rectImageWithKey:selectedTodayImageKey frame:self.selectedDayImageView.frame color:selectedTodayImageColor];
    }
    return selectedTodayImage;
}

- (UIFont *)selectedDayLabelFont
{
    return [UIFont fontWithName:@"SFUIText-Regular" size:17.0f];
}

- (UIColor *)selectedDayLabelTextColor
{
    return [UIColor whiteColor];
}

- (UIColor *)selectedDayImageColor
{
	return [UIColor colorWithRed:50/255.0 green:186/255.0 blue:85/255.0 alpha:1];
}

- (UIImage *)customSelectedDayImage
{
    return nil;
}

- (UIImage *)selectedDayImage
{
    UIImage *selectedDayImage = [self customSelectedDayImage];
    if (!selectedDayImage) {
        UIColor *selectedDayImageColor = [self selectedDayImageColor];
        NSString *selectedDayImageKey = [NSString stringWithFormat:@"img_selected_day_%@", [selectedDayImageColor description]];
        selectedDayImage = [self rectImageWithKey:selectedDayImageKey frame:self.selectedDayImageView.frame color:selectedDayImageColor];
    }
    return selectedDayImage;
}

- (UIColor *)overlayImageColor
{
    return [UIColor colorWithRed:184/255.0f green:184/255.0f blue:184/255.0f alpha:1.0f];
}

- (UIImage *)customOverlayImage
{
    return nil;
}

- (UIImage *)overlayImage
{
    UIImage *overlayImage = [self customOverlayImage];
    if (!overlayImage) {
        UIColor *overlayImageColor = [self overlayImageColor];
        NSString *overlayImageKey = [NSString stringWithFormat:@"img_overlay_%@", [overlayImageColor description]];
        overlayImage = [self rectImageWithKey:overlayImageKey frame:self.overlayImageView.frame color:overlayImageColor];
    }
    return overlayImage;
}

@end
