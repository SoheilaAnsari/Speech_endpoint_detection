 %% SPEECH ENDPOINT DETECTION FROM THE SHORT-TERM ENERGY AND ZERO-CROSSING RATE
%------------------------------------------------------------------------------------------------------
clc;
clear;

max_words=10;% number of words that can be in the input signal
word_length=40;
corrupted_end_length=100;
coef_ITL=16;
coef_ITU=64;
syllable_threshold=180;
fault_detect_threshold=10;

voice_name='1234.wav';
cropped_name='1234_cropped.wav';

[s,fs]= audioread(voice_name);
s=s(:,1);

%ao = audioplayer(s ,fs);
%play (ao);

%win = 'R';
fl = 100; %frame length
inc = 50; %overlap length
w = rectwin(fl);

sm = s-mean(s); % Takes the mean out of data before processing.
speechflag = 0;

% IIR Elliptical BPF Design
d = fdesign.bandpass(100/4000,150/4000,2000/4000,2400/4000,60,0.5,60);
hd = ellip(d);
sf = filter(hd,sm); % Filters the speech data.

% Design of a first-order pre-emphasis filter
a = 1;
b = [1, -15/16];
sf = filter(b,a,sm);

% IIR Elliptical HPF Design
d = fdesign.highpass('n,fst,fp,ap',10,60/4000,100/4000,0.5);
hd = ellip(d);
sf = filter(hd,sm);

% Truncating the data to make it divisible by frame length.
m = floor(length(sf)/inc);  
sf = sf(1:m*inc);

% Short-term energy per frame is STE and Zero crossing count
% per frame is ZCR. % 50 overlaping frames taken by default.
for n=1:m-1;
 sw = (sf(inc*(n-1)+1:inc*(n-1)+fl)).*w; 
 STE(n) = sum(abs(sw));
 for j= 2:fl;
    zc(j)=abs(sign(sw(j))-sign(sw(j-1)))/2;
 end
 ZCR(n) = sum(zc);
end

% Assuming there is no speech during the first 100 ms of recordings,
% Mean and standard deviation of ZCR and STE for the first ten frames.
avgzcr = mean(ZCR(1:10)); stdzcr = std(ZCR(1:10));
avgste = mean(STE(1:10)); stdste = std(STE(1:10));

% Setting up STE Upper and Lower Thresholds and ZCR Threshold.
IF = fl/4; 
IZCT = min(IF,avgzcr+stdzcr); % Zero-crossing Rate Threshold.
IE = 0.15; % Upper level for avgste in case high noise
% present in first 20 frames.
minste = min(IE,avgste+stdste);
ITL = coef_ITL*minste; % Lower threshold for STE.
ITU= coef_ITU*minste; % Upper threshold for STE.
FT = (ITU-ITL)/2 + ITL; % Fine threshold for STE.

% Following algorithm firsts makes a raw search for endpoint detection
% based on STE, ITU and ITL. Then it refines the speech boundaries using
% ZCR and IZCT for the successive and preceding 6 frames forth and back.
% If the interval btwn rawstart and rawend is less than 100 ms (20 frames)
% algorithm assumes that it is just a click noise (or a spike), not speech.

duration = 0; rawend = 0; rawstart = 0; loopn =0; d = 1; refindex = 0; speech_end=0;
counter=0;fault_detect=0;
RM=zeros(max_words+1,4); % Result Matrice

while (~speech_end)
% Raw search for the starting frame 
for n = d:m-1
  if STE(n) > ITU;
   refindex = n; rawstart = n;
   for l = refindex:-1.0:d
    if STE(l) < FT; rawstart = l; break; end
   end
 break;
 end
end

% Raw search for the ending frame
 if refindex ~= 0;
for k = refindex:m-1
 if STE(k) < FT; rawend = k; break; end
end
 end

% Fine search using total number of intervals crossing threshold of ZCR.
finestart = rawstart; fineend = rawend;

% Fine search for the starting frame using ZCR
nzc = 0; update = 0;
if (rawstart-6) > 0;
for n = rawstart:-1:(rawstart-6)
 if ZCR(n) > IZCT; nzc = nzc+1; update = n; end
end
if nzc > 3; finestart = update; end
end

% Fine search for the ending frame using ZCR
nzc = 0; update = 0;
if ((rawend+6) < length(ZCR))&&(rawend ~= 0);
for n = rawend:(rawend+6)
 if ZCR(n) > IZCT; nzc = nzc+1; update = n; end
end
 if nzc > 3; fineend = update; end
end

starti = inc*(finestart)+1;
endi = inc*(fineend);

%% Generating speechflag 
    duration=rawend-rawstart;    
    if ((counter~=0)&&((finestart-RM(counter,2))<syllable_threshold))
        RM(counter,2)=fineend;
        RM(counter,3)= fineend-RM(counter,1);
    else
        if(duration>word_length)
            counter=counter+1;
            RM(counter,1)= finestart;
            RM(counter,2)= fineend;
            RM(counter,3)= fineend-finestart;
            if (duration == 0); RM(counter+1,4)=-1; end
            if (duration < 0); RM(counter+1,4)=-1; end
        else
            fault_detect=fault_detect+1;
            if(fault_detect>fault_detect_threshold) speech_end=1; break; end;
        end
     end
     if counter >= max_words speech_end = 1; break; end 
     d = fineend+1;
     if (d>=(m-corrupted_end_length)) speech_end = 1; break; end
     loopn=loopn+1; 
     if (loopn >= fault_detect_threshold+max_words) break; end;
     %rawstart=0;
     %rawend=0; 
    
end

% Plotting of STE, ZCR, and original speech signal, thresholds and resulting
% endpoints on the speech signal.
%% Figure 1
figure(1);

% Plotting Short Term Energy
subplot(3,1,1); 
plot([RM(1,1) RM(1,1)], [min(STE) 1.1*max(STE)],'color','r'); hold on,
plot([RM(1,2) RM(1,2)], [min(STE) 1.1*max(STE)],'color','g');
legend ('Starting frame', 'Ending frame','location','west');
for i=1:1:max_words-1
   if (RM(1+i,1)~=0)
    plot([RM(1+i,1) RM(1+i,1)], [min(STE) 1.1*max(STE)],'color','r'); hold on,
    plot([RM(1+i,2) RM(1+i,2)], [min(STE) 1.1*max(STE)],'color','g');
   end
end
plot(STE); hold on,
plot([1 length(STE)], [ITU ITU],'--','color','r');
plot([1 length(STE)], [ITL ITL],'--','color','g');
ylim([0 1.1*max(STE)])
xlim([0 length(STE)])
title('Abs. Magnitude Energy'); ylabel('Amplitude'); xlabel('Frame Number');

% Plotting ZCR
 subplot(3,1,2);
 plot([RM(1,1) RM(1,1)], [min(ZCR) 1.1*max(ZCR)],'color','r'); hold on;
 plot([RM(1,2) RM(1,2)], [min(ZCR) 1.1*max(ZCR)],'color','g');
 %legend ('Starting frame', 'Ending frame');
for i=1:1:max_words-1
   if (RM(1+i,1)~=0)
    plot([RM(1+i,1) RM(1+i,1)], [min(ZCR) 1.1*max(ZCR)],'color','r'); hold on,
    plot([RM(1+i,2) RM(1+i,2)], [min(ZCR) 1.1*max(ZCR)],'color','g');
   end
end
 plot(ZCR);
 plot(1:1:length(ZCR),IZCT.*ones(length(ZCR)),'--','color','r');
 ylim([0 1.1*max(ZCR)])
 xlim([0 length(ZCR)])
 title('Zero-crossing Rate'); ylabel('Zero-crossings');
 xlabel('Frame Number');

 % Plotting Speech Signal VS sample number
 subplot(3,1,3); 
 plot([inc*RM(1,1)+1 inc*RM(1,1)+1], [min(s) 1.1*max(s)],'color','r'); hold on;
 plot([inc*RM(1,2) inc*RM(1,2)], [min(s) 1.1*max(s)],'color','g');
 %legend ('Starting frame', 'Ending frame');
 for i=1:1:max_words-1
   if (RM(1+i,1)~=0)
    plot([inc*RM(1+i,1)+1 inc*RM(1+i,1)+1], [min(s) 1.1*max(s)],'color','r'); hold on,
    plot([inc*RM(1+i,2) inc*RM(1+i,2)], [min(s) 1.1*max(s)],'color','g');
   end
end
 plot(s); 
 title('End & starting points of the speech'); ylabel('Amplitude');
 xlabel('Sample Number');
 ylim([1.1*min(s) 1.1*max(s)])

figure(1)
set(findall(gcf,'-property','FontSize'),'FontSize',10);
set(findall(gcf,'-property','FontWeight'),'FontWeight','normal');
set(findall(gcf,'-property','FontName'),'FontName','Times New Roman');
set(findall(gcf,'-property','marker'),'markersize',5)
%export_fig(gcf,'png','-r600','ottf_STE_ZCR');
 %% 
concat_cropped_sf=zeros(1,1);
for i=1:1:max_words
    if((RM(i,1)~=0)&&(RM(i,2)~=0))
        concat_cropped_sf=vertcat(concat_cropped_sf, sf(inc*RM(i,1)+1:inc*RM(i,2),1));
    end
end
%wavwrite(concat_cropped_sf,fs,cropped_name)% the output signal
audiowrite('cropped_name.wav', concat_cropped_sf , fs);

%v = audioread('four_cropped.wav');
%ao = audioplayer(v,fs);
%play(ao);
%% Figure 2
figure(2);
plot(concat_cropped_sf);
xlim([0 length(concat_cropped_sf)])
title('Cropped speech signal'); 
ylabel('Amplitude');
xlabel('Sample Number');

set(findall(gcf,'-property','FontSize'),'FontSize',10);
set(findall(gcf,'-property','FontWeight'),'FontWeight','normal');
set(findall(gcf,'-property','FontName'),'FontName','Times New Roman');
set(findall(gcf,'-property','marker'),'markersize',5)
%export_fig(gcf,'png','-r600','count_Cropped');
