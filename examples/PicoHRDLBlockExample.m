%% PicoLog High-Resolution Data Logger Series Block Capture Example
%
% This script demonstrates how to:
%
% * Open a connection to a PicoLog High-Resolution Data Logger
% * Display unit information
% * Set a channel
% * Start collection data for a block capture
% * Take readings
% * Plot data
% * Close the connection to the unit
%
% Please refer to the
% <https://www.picotech.com/download/manuals/adc20-adc24-high-resolution-data-logger-users-guide.pdf ADC-20/ADC-24 High-Resolution Data Logger's Guide> for further information.
% This file can be edited to suit application requirements.
%
% *Copyright:* � 2018 Pico Technology Ltd. See LICENSE file for terms.

%% Clear console and close figures

clc;
close all;

%% Load configuration information

PicoHRDLConfig;

%% Define any variables to be used throughout the script

numChannels = 0; % The number of channels on the device.

hasDigitalPorts = PicoConstants.FALSE;
digitalPortsEnabled = PicoConstants.FALSE;

%% Load shared library

% Indentify architecture and obtain function handle for the correct
% prototype file.
    
archStr = computer('arch');

picoHRDLMFile = str2func(strcat('picohrdlMFile_', archStr));

if (~libisloaded('picohrdl'))

	if ismac()
	   
		[picohrdlNotFound, picohrdlWarnings] = loadlibrary('libpicohrdl.dylib', picoHRDLMFile, 'alias', 'picohrdl');
		
		% Check if the library is loaded
		if ~libisloaded('picohrdl')
		
			error('PicoHRDLGetSingleValueExample:LibaryNotLoaded', 'Library libpicohrdl.dylib not loaded.');
		
		end
		
	elseif isunix()
		
		[picohrdlNotFound, picohrdlWarnings] = loadlibrary('libpicohrdl.so', picoHRDLMFile, 'alias', 'picohrdl');
		
		% Check if the library is loaded
		if ~libisloaded('picohrdl')
		
			error('PicoHRDLGetSingleValueExample:LibaryNotLoaded', 'Library libpicohrdl.so not loaded.');
		
		end
		
	elseif ispc()
		
		[picohrdlNotFound, picohrdlWarnings] = loadlibrary('picohrdl.dll', picoHRDLMFile);
		
		% Check if the library is loaded
		if ~libisloaded('picohrdl')
		
			error('PicoHRDLGetSingleValueExample:LibaryNotLoaded', 'Library picohrdl.dll not loaded.');
		
		end
		
	else
		
		error('PicoHRDLGetSingleValueExample:OSNotSupported', 'Operating system not supported, please contact support@picotech.com');
		
	end
	
end

%% Open a connection

hrdlHandle = calllib('picohrdl', 'HRDLOpenUnit');

if (hrdlHandle >= 1)
    
    fprintf('Device handle: %d\n', hrdlHandle);
    
elseif (hrdlHandle == 0)
   
    error('PicoHRDLGetSingleValueExample:UnitNotFound', 'No device found.');
    
else
    
    error('PicoHRDLGetSingleValueExample:FailedToOpen', 'Failed to open device.');
    
end

%% Display unit information

infoString = blanks(100);
status.getInfo = zeros(7, 1, 'int16');

fprintf('\nUnit information:-\n\n');

information = {'Driver version: ', 'USB Version: ', 'Hardware version: ', 'Variant: ', 'Batch/Serial: ', 'Cal. date: ', 'Kernel driver version: '};

for i = 0:(length(information) - 1)
    
    [status.getInfo(i + 1, 1), infoString1] = calllib('picohrdl', 'HRDLGetUnitInfo', hrdlHandle, infoString, length(infoString), i);
    
    disp([information{i + 1} infoString1]);
    
    % Only the ADC-24 has digital ports
    if (i == 3)
    
        if (infoString1 == PicoHRDLConstants.MODEL_ADC_24)
           
            hasDigitalPorts = PicoConstants.TRUE;
            numChannels = PicoHRDLConstants.ADC_24_SINGLE_ENDED_CHANNELS;
            
        elseif (infoString1 == PicoHRDLConstants.MODEL_ADC_20)
            
            hasDigitalPorts = PicoConstants.FALSE;
            numChannels = PicoHRDLConstants.ADC_20_SINGLE_ENDED_CHANNELS;
            
        else
            
            hasDigitalPorts = PicoConstants.FALSE;
            numChannels = 0;
            
        end
        
    end
        
end

fprintf('\n');

%% Set mains noise rejection to 50 Hz

[status.setMains] = calllib('picohrdl', 'HRDLSetMains', hrdlHandle, 0);

%% Set channel 

channel1        = picohrdlEnuminfo.enHRDLInputs.HRDL_ANALOG_IN_CHANNEL_1;
ch1Enabled      = PicoConstants.TRUE;
ch1Range        = picohrdlEnuminfo.enHRDLRange.HRDL_2500_MV;
ch1SingleEnded  = PicoConstants.TRUE;

[status.setAnalogInCh1] = calllib('picohrdl', 'HRDLSetAnalogInChannel', hrdlHandle, channel1, ch1Enabled, ch1Range, ch1SingleEnded);

%% Get minimum and maximum ADC counts available for the channel
% Odd and even numbered channels have a different max/min ADC count.
% For differential channels, the information is only required for the
% odd-numbered channel.

ch1MinAdcPtr = libpointer('int32Ptr', 0);
ch1MaxAdcPtr = libpointer('int32Ptr', 0) ;

[status.getMinMaxAdcCounts] = calllib('picohrdl', 'HRDLGetMinMaxAdcCounts', hrdlHandle, ...
    ch1MinAdcPtr, ch1MaxAdcPtr, channel1);

ch1MinAdc = ch1MinAdcPtr.Value;
ch1MaxAdc = double(ch1MaxAdcPtr.Value);

%% Set digital I/O (ADC-24 only)
% Set digital pin 1 to input, rest as outputs

if (hasDigitalPorts > 0)
    
    directionOut = picohrdlEnuminfo.enHRDLDigitalIoChannel.HRDL_DIGITAL_IO_CHANNEL_2 + picohrdlEnuminfo.enHRDLDigitalIoChannel.HRDL_DIGITAL_IO_CHANNEL_3 + picohrdlEnuminfo.enHRDLDigitalIoChannel.HRDL_DIGITAL_IO_CHANNEL_4;
    digitalOutPinState = picohrdlEnuminfo.enHRDLDigitalIoChannel.HRDL_DIGITAL_IO_CHANNEL_2; % Set digital I/O to high, others will remain as low.
    enabledDigitalIn = picohrdlEnuminfo.enHRDLDigitalIoChannel.HRDL_DIGITAL_IO_CHANNEL_1;
    
    if (enabledDigitalIn > 0)
       
        digitalPortsEnabled = PicoConstants.TRUE;
        
    end
    
    [status.setDigitalIOChannel] = calllib('picohrdl', 'HRDLSetDigitalIOChannel', hrdlHandle, directionOut, digitalOutPinState, enabledDigitalIn);
    
end

%% Query the number of enabled channels
% This function returns the number of enabled analog channels on the
% device.

numEnabledChPtr = libpointer('int16Ptr', 0);

[status.getNumberOfEnabledChannels] = calllib('picohrdl', 'HRDLGetNumberOfEnabledChannels', hrdlHandle, numEnabledChPtr);

numEnabledChannels = numEnabledChPtr.Value;

% Update the number of enabled channels if a digital port has been set as
% an input (ADC-24 only).
if (hasDigitalPorts == PicoConstants.TRUE && digitalPortsEnabled == 1)
   
    numEnabledChannels = numEnabledChannels + 1;
    
end

disp(['Number of enabled channels: ', num2str(numEnabledChannels)]);

%% Set the collection time interval
% Collect data at 1 second time intervals. All conversions should take
% place within the time specified. Digital inputs are instantaneous so do
% not need to be included when calculating the time interval.

sampleIntervalMs = 1000; % Milliseconds
conversionTimeCh1 = picohrdlEnuminfo.enHRDLConversionTime.HRDL_100MS;

%% Collect a block of data
% Collect data for 30 seconds

numValuesPerChannel = 30;
method              = picohrdlEnuminfo.enBlockMethod.HRDL_BM_BLOCK;
isReady             = 0;

disp('Starting data collection...');

[status.run] = calllib('picohrdl', 'HRDLRun', hrdlHandle, numValuesPerChannel, method);

% Poll the driver until the device has completed data collection.
while (isReady == 0)
    
    isReady = calllib('picohrdl', 'HRDLReady', hrdlHandle);
    fprintf('.');
    pause(1);

end

disp('Data collection complete.');

%% Retrieve the data

% Allocate times and data buffer that will be large enough to accomodate
% all the readings.

times       = [];
timesPtr    = libpointer('int32Ptr', zeros(numValuesPerChannel, 1, 'int32'));
values      = [];
valuesPtr   = libpointer('int32Ptr', zeros(numEnabledChannels * numValuesPerChannel, 1, 'int32'));
overflow    = 0;
overflowPtr = libpointer('int16Ptr', 0);

numValuesCollectedPerChannel = calllib('picohrdl', 'HRDLGetTimesAndValues', hrdlHandle, timesPtr, valuesPtr, overflowPtr, numValuesPerChannel);

if (numValuesCollectedPerChannel > 0)
   
    times = timesPtr.Value;
    values = valuesPtr.Value;
    overflow = overflowPtr.Value;
    
else
    
    error('PicoHRDLBlockExample:NoDataValuesCollected', 'HRDLGetTimesAndValues() - No data values were collected.');
    
end

% Extract data for each channel
digitalData = values(1:numEnabledChannels:end);
channel1Data = values(2:numEnabledChannels:end);

% Convert channel 1 data to volts
channel1Data = picohrdladc2volts(channel1Data, ch1Range, ch1MaxAdc);

% Digital data is stored as bit flags - use bit shift if using I/O pins
% 2, 3 and/or 4 as inputs.
digitalIO1Data = bitand(digitalData, hex2dec('1'));

%% Plot the data

figure1 = figure('Name','PicoLog High-Resolution Data Logger Example - Block Data Capture', 'NumberTitle','off');
axes1 = axes('Parent', figure1);

% Channel 1 data
subplot(2, 1, 1)

plot(times, channel1Data);
title('Voltage vs. Time')
xlabel('Time (ms)');
ylabel('Voltage (V)');
ylim([-vMaxCh1 vMaxCh1]);
legend('Ch. 1');
grid on;

% Digital I/O pin 1 data
subplot(2, 1, 2)

plot(times, digitalIO1Data);
title('Digital Input State vs. Time')
xlabel('Time (ms)');
ylabel('State');
ylim([0 1]);
legend('D1');
grid on;

%% Close the connection

closeStatus = calllib('picohrdl', 'HRDLCloseUnit', hrdlHandle);

%% Unload the library

unloadlibrary('picohrdl');