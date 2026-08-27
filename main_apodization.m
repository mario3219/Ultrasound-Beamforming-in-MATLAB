clc,clear

imageA = beamformImage("PreRF_ImageA.mat");
imageB = beamformImage("PreRF_ImageB.mat");
imageC = beamformImage("PreRF_ImageC.mat");
ImagePostRF = PostRFImage;

subplot(221),imagesc(imageA),colormap(gray),title("ImageA");
subplot(222),imagesc(imageB),colormap(gray),title("ImageB");
subplot(223),imagesc(imageC),colormap(gray),title("ImageC");
subplot(224),imagesc(ImagePostRF),colormap(gray),title("ImagePostRF");

% Dynamic focusing
function Image = beamformImage(ImageName)
    fprintf("Beamforming " + ImageName + " with apodization" + "..." + "\n");
    % ladda data
    load(ImageName);
    Fs = preBeamformed.SampleFreq;
    pitch = preBeamformed.Pitch; % Distance between elements
    c = preBeamformed.SoundVel; % Velocity
    deadzone = preBeamformed.DeadZone; % Deadzone
    channels = preBeamformed.Channels;
    
    % Beräkna sampel djup
    % samples 0->2048 motsvarar amplituder som funktion av tid, så sampel 100
    % motsvarar ett djup, sampel 300 ett annat osv...
    depths = (1:2048)*c/(Fs)+deadzone; %meter
    
    % tom beamformed image, där varje focused linje ska lagras
    beamformedImage = zeros(2048,128); 

    % Apodization window
    apodization = hanning(channels);  % Hanning apodization
    
    for line = 1:1:128
        %hämta data för en linje, 2048x64
        line_data = preBeamformed.Signal(:,:,line);
    
        %tom vektor för en fokuserad linje
        focused_line = zeros(2048,1);
    
        for element = 1:1:channels
            %iterera varje sampel, som motsvarar ett viss djup
            for sample = 1:1:2048
    
                %hämta djupet för en sampel, motsvarar djupet för mitten elementet
                %därav fokus djupet
                depth = depths(sample);
    
                %tiden det tar för mitten elementet att få en signal
                time_middle = 2.05*depth/c;            
                %time_middle = 2*depth/c; 
                % Ändrad från 2 till 2.05, bättre lateral upplösning
                % (vet inte varför, blev så efter att ha lekt runt med värdet) 
    
                %beräkna avståndet från elementet som ska delayas till mitten
                %elementet, pitch=avstånd från mitt till mitt av element, 0.5:
                %avstånd från element till absolut mitt (jämnt antal element)
                dx = pitch*abs(channels/2-element);
               % dx = pitch*abs(channels/2-element+0.5);
               % Utan 0.5 blir lateral resolution bättre
               % (vet inte varför, blev så efter att ha lekt runt med värdet) 
    
                %beräkna avståndet från elementet som ska delayas till fokus
                %punkten
                d = sqrt(dx^2+depth^2);
    
                %beräkna tiden för ekot från elementet som ska delayas till
                %fokus punkten
                time = 2*d/c;
    
                %delay som ska sättas blir skillnaden mellan tiden för mitten
                %elementet och tiden för elementet som ska delayas
                delay = time-time_middle;
    
                %överför till sample delay
                sample_delay = round(delay*Fs);
    
                %hitta sampeln som är den egentliga som ska användas
                fixed_sample = sample+sample_delay;
    
                % if-sats, om delayed sample ligger out-of-bounds eller är av
                % negativ index
                if fixed_sample > 0 && fixed_sample <= 2048
                    %sparar den riktiga sampeln som ska användas, som hittats i
                    %hänsyn till delay, och summerar med alla andra lagrade
                    %samples
                    weighted_signal = apodization(element) * line_data(fixed_sample, element);
                    focused_line(sample) = focused_line(sample) + weighted_signal;
                end
            end
        end
        %efter att ha summerat alla 64 element så har en linje formats, lägg
        %till i indexerad plats i beamform image
        beamformedImage(:,line) = focused_line;
    end
    beamformedImage = highpass(beamformedImage,4e6,Fs);
    Image=abs(hilbert(beamformedImage)); %where the fpostbeamformed"-variable is already filtered 
end

% Post-rf bild för jämförelse
function Image = PostRFImage
    fprintf("Processing PostRF..." + "\n");
    load("PostRF_Phantom.mat");
    data = PostRF.Signal;
    Image=abs(hilbert(data)); %where the fpostbeamformed"-variable is already filtered 
end

% Inspect image before beamforming
function Image = preBeamformImage(ImageName)
    fprintf("Processing PreBeamformed " + ImageName + "..." + "\n");
    load(ImageName);
    Fs = preBeamformed.SampleFreq;
    
    prebeamformed = preBeamformed.Signal;
    
    ThreeToTwo=squeeze(sum(prebeamformed,2));
    ThreeToTwo = highpass(ThreeToTwo,4e6,Fs);
    Image=abs(hilbert(ThreeToTwo));
end
