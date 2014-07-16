//
//  SPCLoader.m
//  SPCLoader
//
//  Created by bcharron on 2014-07-16.
//  Copyright (c) 2014 Benjamin Charron. All rights reserved.
//

#import "SPCLoader.h"

#define SPC_MAGIC "SNES-SPC700 Sound File Data"
#define SPC_DATA_OFFSET 0x0100
#define SPC_VERSION_OFFSET 0x0024
#define SPC_IPL_ROM_OFFSET 0xFFC0

@implementation SPCLoader {
        NSObject<HPHopperServices> *_services;
}

- (instancetype)initWithHopperServices:(NSObject<HPHopperServices> *)services {
    if (self = [super init]) {
        _services = services;
    }
    return self;
}

- (UUID *)pluginUUID {
    return([_services UUIDWithString:@"4f111350-0c9f-11e4-9191-0800200c9a66"]);
}

- (HopperPluginType)pluginType {
    return(Plugin_Loader);
}

- (NSString *)pluginName {
    return(@"SPC File (SNES Music File)");
}

- (NSString *)pluginDescription {
    return(@"SPC File Loader (SNES Music File)");
}

- (NSString *)pluginAuthor {
    return(@"Benjamin Charron");
}

- (NSString *)pluginCopyright {
    return(@"Copyright (C) 2014 Benjamin Charron");
}

- (NSString *)pluginVersion {
    return(@"0.1.0");
}


- (BOOL)canLoadDebugFiles {
    return(NO);
}

/// Returns an array of DetectedFileType objects.
- (NSArray *)detectedTypesForData:(NSData *)data {
    const void *bytes = (const void *)[data bytes];

    if (strncmp(SPC_MAGIC, (const char *) bytes, strlen(SPC_MAGIC)) == 0) {
        NSObject<HPDetectedFileType> *type = [_services detectedType];
        [type setFileDescription:@"SPC File (SNES Music File)"];
        [type setAddressWidth:AW_32bits];
        [type setCpuFamily:@"sony"];
        [type setCpuSubFamily:@"SPC700"];
        return @[type];
    }
    return (@[]);
}

/// Load a file.
/// The plugin should create HPSegment and HPSection objects.
/// It should also fill information about the CPU by setting the CPU family, the CPU subfamily and optionally the CPU plugin UUID.
/// The CPU plugin UUID should be set ONLY if you want a specific CPU plugin to be used. If you don't set it, it will be later set by Hopper.
/// During long operations, you should call the provided "callback" block to give a feedback to the user on the loading process.
- (FileLoaderLoadingStatus)loadData:(NSData *)data usingDetectedFileType:(DetectedFileType *)fileType options:(FileLoaderOptions)options forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    const uint8_t *bytes = (const uint8_t *)[data bytes];
    
    if (strncmp(SPC_MAGIC, (const char *) bytes, strlen(SPC_MAGIC)) != 0) {
        return(DIS_NotSupported);
    }
    
    uint8_t version = bytes[SPC_VERSION_OFFSET];
    if (version != 30) {
        NSLog(@"ERROR: Unsupported SPC file version, %d", version);
    }
    
    NSString *msg = [NSString stringWithFormat:@"SPC File version: %d", version];
    [_services logMessage:msg];
    
    file.cpuFamily = @"sony";
    file.cpuSubFamily = @"SPC700";
    [file setAddressSpaceWidthInBits:32];
    
    uint16_t pc = OSReadLittleInt16(bytes, 0x25);

    NSObject<HPSegment> *segment = [file addSegmentAt:0x0000 size:0x10000];
    segment.segmentName = @"Memory";
    
    NSData *segmentData = [NSData dataWithBytes:&bytes[SPC_DATA_OFFSET] length:0x10000];

    segment.mappedData = segmentData;
    segment.fileOffset = SPC_DATA_OFFSET;
    segment.fileLength = 0x10000;

    NSObject<HPSection> *page0_section = [segment addSectionAt:0x0000 size:0x00F0];
    page0_section.sectionName = @"Page 0";
    page0_section.containsCode = NO;

    NSObject<HPSection> *registers_section = [segment addSectionAt:0x00F0 size:0x0010];
    registers_section.sectionName = @"Registers";
    registers_section.containsCode = NO;
    
    NSObject<HPSection> *page1_section = [segment addSectionAt:0x0100 size:0x0100];
    page1_section.sectionName = @"Page 1";
    page1_section.containsCode = NO;
    
    NSObject<HPSection> *ram_section = [segment addSectionAt:0x0200 size:0xFFBF - 0x200 + 1];
    ram_section.sectionName = @"RAM";
    ram_section.containsCode = YES;

    NSObject<HPSection> *ipl_section = [segment addSectionAt:0xFFC0 size:0xFFFF - 0xFFC0 + 1];
    ipl_section.sectionName = @"IPL_ROM";
    ipl_section.containsCode = YES;
    ipl_section.pureCodeSection = YES;
    
    [file setName:@"CTRLREG" forVirtualAddress:0x00F1];
    [file setName:@"DSPRegisterAddress" forVirtualAddress:0x00F2];
    [file setName:@"DSPRegisterData" forVirtualAddress:0x00F3];
    [file setName:@"PORT0" forVirtualAddress:0x00F4];
    [file setName:@"PORT1" forVirtualAddress:0x00F5];
    [file setName:@"PORT2" forVirtualAddress:0x00F6];
    [file setName:@"PORT3" forVirtualAddress:0x00F7];
    [file setName:@"TIMER0" forVirtualAddress:0x00FA];
    [file setName:@"TIMER1" forVirtualAddress:0x00FB];
    [file setName:@"TIMER2" forVirtualAddress:0x00FC];
    [file setName:@"COUNTER0" forVirtualAddress:0x00FD];
    [file setName:@"COUNTER1" forVirtualAddress:0x00FE];
    [file setName:@"COUNTER2" forVirtualAddress:0x00FF];
    [file setName:@"IPL_ROM" forVirtualAddress:0xFFC0];

    // Entry points / procedures
    [file addEntryPoint:pc];
    [file addPotentialProcedure:SPC_IPL_ROM_OFFSET];

    return(DIS_OK);
}

- (FileLoaderLoadingStatus)loadDebugData:(NSData *)data forFile:(NSObject<HPDisassembledFile> *)file usingCallback:(FileLoadingCallbackInfo)callback {
    return(DIS_NotSupported);
}

/// Extract a file
/// In the case of a "composite loader", extract the NSData object of the selected file.
- (NSData *)extractFromData:(NSData *)data
      usingDetectedFileType:(DetectedFileType *)fileType
         returnAdjustOffset:(uint64_t *)adjustOffset {
    return(nil);
}

@end
