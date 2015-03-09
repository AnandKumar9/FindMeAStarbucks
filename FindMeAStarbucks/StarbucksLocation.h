//
//  StarbucksLocation.h
//  FindMeAStarbucks
//
//  Created by Anand Kumar 5 on 3/7/15.
//  Copyright (c) 2015 OutOnAWeekend. All rights reserved.
//

#import <Foundation/Foundation.h>
@import MapKit;

@interface StarbucksLocation : NSObject

@property (nonatomic) MKMapItem *mapItem;
@property (nonatomic) MKPointAnnotation *annotation;

@end
