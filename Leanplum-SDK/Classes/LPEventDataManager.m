//
//  LPEventDataManager.m
//  Leanplum
//
//  Created by Alexis Oyama on 6/9/17.
//  Copyright (c) 2017 Leanplum, Inc. All rights reserved.
//
//  Licensed to the Apache Software Foundation (ASF) under one
//  or more contributor license agreements.  See the NOTICE file
//  distributed with this work for additional information
//  regarding copyright ownership.  The ASF licenses this file
//  to you under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing,
//  software distributed under the License is distributed on an
//  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
//  KIND, either express or implied.  See the License for the
//  specific language governing permissions and limitations
//  under the License.

#import "LPEventDataManager.h"
#import "LPDatabase.h"
#import "LPJSON.h"
#import "LPRequestStorage.h"

@implementation LPEventDataManager

+ (void)load
{
    [LPEventDataManager migrateRequests];
}

+ (void)migrateRequests
{
    LPRequestStorage *requestStorage = [LPRequestStorage sharedStorage];
    if ([[NSFileManager defaultManager] fileExistsAtPath:requestStorage.documentsFilePath]) {
        NSArray *requests = [requestStorage popAllRequests];
        [LPEventDataManager addEvents:requests];
    }
}

+ (void)addEvent:(NSDictionary *)event
{
    NSString *query = @"INSERT INTO event (data) VALUES (?);";
    NSArray *objectsToBind = @[[LPJSON stringFromJSON:event]];
    [[LPDatabase database] runQuery:query bindObjects:objectsToBind];
}

+ (void)addEvents:(NSArray *)events
{
    if (!events.count) {
        return;
    }
    
    NSMutableString *query = [@"INSERT INTO event (data) VALUES " mutableCopy];
    NSMutableArray *objectsToBind = [NSMutableArray new];
    [events enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *postfix = idx >= events.count-1 ? @";" : @",";
        NSString *valueString = [NSString stringWithFormat:@"(?)%@", postfix];
        [query appendString:valueString];
        
        NSString *objString = [LPJSON stringFromJSON:obj];
        [objectsToBind addObject:objString];
    }];
    [[LPDatabase database] runQuery:query bindObjects:objectsToBind];
}

+ (NSArray *)eventsWithLimit:(NSInteger)limit
{
    NSString *query = [NSString stringWithFormat:@"SELECT data FROM event ORDER BY rowid "
                                                  "LIMIT %ld", limit];
    NSArray *rows = [[LPDatabase database] rowsFromQuery:query];
    
    // Convert row data to event.
    NSMutableArray *events = [NSMutableArray new];
    for (NSDictionary *row in rows) {
        NSDictionary *event = [LPJSON JSONFromString:row[@"data"]];
        if (!event || !event.count) {
            continue;
        }
        [events addObject:[event mutableCopy]];
    }
    
    return events;
}

+ (void)deleteEventsWithLimit:(NSInteger)limit
{
    NSString *query = [NSString stringWithFormat:@"DELETE FROM event ORDER BY rowid "
                                                  "LIMIT %ld", limit];
    [[LPDatabase database] runQuery:query];
}

@end
