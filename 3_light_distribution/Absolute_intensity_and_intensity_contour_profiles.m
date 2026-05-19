%% =========================================================
%% Beam Analysis — SIDE + BOTTOM (parameters + figures)
%% =========================================================

clear; clc;

%% === Schakelaars ===
ENABLE_SIDE   = true;
ENABLE_BOTTOM = true;

%% === METADATA inlezen ===
meta = readtable('metadata light experiment.csv');

fileList = meta.file;
fiberID  = meta.fiberID;
lambda   = meta.lambda;
depth    = meta.depth;
height   = meta.height;
view     = meta.view;
nFiles   = numel(fileList);

%% === Stap 1: alle beelden laden + maskeren ===
images = cell(nFiles,1);

for k = 1:nFiles

    if strcmp(view{k}, 'side') && ~ENABLE_SIDE
        continue
    end
    if strcmp(view{k}, 'bottom') && ~ENABLE_BOTTOM
        continue
    end
    if strcmp(view{k}, 'side') && height(k) ~= 4.5
        continue
    end

    img = imread(fileList{k});
    if ndims(img) == 3
        img = im2gray(img);
    end
    img = double(img);

    [H, W] = size(img);

    if strcmp(view{k}, 'side')
        cutTop = round(0.22 * H);
        img(1:cutTop, :) = 0;
    else
        cutTop    = round(0.10 * H);
        cutBot    = round(0.90 * H);
        cutLeft   = round(0.27 * W);
        cutRight  = round(0.80 * W);

        img(1:cutTop, :) = 0;
        img(cutBot:end, :) = 0;
        img(:, 1:cutLeft) = 0;
        img(:, cutRight:end) = 0;
    end

    images{k} = img;
end

%% === Stap 2: per-(view,lambda) globalMax bepalen ===
lambdaVals = unique(lambda);
viewVals   = unique(view);

globalMax_map = containers.Map('KeyType','char','ValueType','double');

for v = viewVals.'
    for L = lambdaVals.'
        idx = strcmp(view, v{1}) & (lambda == L);
        maxVL = 0;
        for k = find(idx).'
            if isempty(images{k}), continue; end
            maxVL = max(maxVL, max(images{k}(:)));
        end
        key = sprintf('%s_%dnm', v{1}, L);
        globalMax_map(key) = maxVL;
    end
end

%% === Pixel size ===
pixelSize = 1;

%% === Outputmappen ===
outSide   = 'Results_Side_adapted_titles';
outBottom = 'Results_Bottom_adapted_titles';

if ~exist(outSide,'dir'),   mkdir(outSide);   end
if ~exist(outBottom,'dir'), mkdir(outBottom); end

%% === Parameter tabel ===
results = table();

%% =========================================================
%% LOOP OVER BEELDEN
%% =========================================================
for k = 1:nFiles

    if isempty(images{k})
        continue
    end

    img_gray = images{k};
    [H, W] = size(img_gray);

    thisView   = view{k};
    thisLambda = lambda(k);
    thisFiber  = fiberID{k};
    thisFile   = fileList{k};

    if strcmp(thisView,'side') && ~ENABLE_SIDE
        continue
    end
    if strcmp(thisView,'bottom') && ~ENABLE_BOTTOM
        continue
    end

    %% 1. Peak zoeken
    maxVal = max(img_gray(:));
    [yTop, xTop] = find(img_gray >= 0.99 * maxVal);
    xPeak = mean(xTop);
    yPeak = mean(yTop);

    %% 2. Coords
    xPix = 1:W;
    yPix = 1:H;

    xPosFull = (xPix - xPeak) * pixelSize;
    yPosFull = (yPix - yPeak) * pixelSize;

    %% 3. Zoom-window
    zoomX_left   = -600;
    zoomX_right  =  600;
    zoomY_top    = -500;
    zoomY_bottom =  700;

    xMask = (xPosFull >= zoomX_left)  & (xPosFull <= zoomX_right);
    yMask = (yPosFull >= zoomY_top)   & (yPosFull <= zoomY_bottom);

    xPos = xPosFull(xMask);
    yPos = yPosFull(yMask);

    croppedImg = img_gray(yMask, xMask);

    %% === ROBUUSTHEID: als croppedImg leeg is → alleen parameters, geen figuren ===
    if isempty(croppedImg)
        FWHM_x = NaN;
        FWHM_y = NaN;
        area_100pct = 0;
        area_75pct  = 0;
        area_50pct  = 0;
        area_25pct  = 0;
        area_5pct   = 0;
        depth50pct  = NaN;
        height50pct = NaN;

        results = [results; table( ...
            string(thisFile), string(thisFiber), thisLambda, depth(k), height(k), ...
            FWHM_x, FWHM_y, ...
            area_100pct, area_75pct, area_50pct, area_25pct, area_5pct, ...
            depth50pct, height50pct ...
        )];

        continue
    end

    %% 4. GlobalMax
    key = sprintf('%s_%dnm', thisView, thisLambda);
    globalMax = globalMax_map(key);

    %% === Mappenstructuur voor figuren ===
    if strcmp(thisView,'side')
        baseDir = outSide;
    else
        baseDir = outBottom;
    end

    lambdaDir = fullfile(baseDir, sprintf('%dnm', thisLambda));
    if ~exist(lambdaDir,'dir'), mkdir(lambdaDir); end

    fiberDir = fullfile(lambdaDir, ['Fiber_' thisFiber]);
    if ~exist(fiberDir,'dir'), mkdir(fiberDir); end

    [~, shortName, ~] = fileparts(thisFile);

    %% =====================================================
    %% FIGURE 1 — Absolute intensiteit
    %% =====================================================
    fig1 = figure('Visible','off');
    imagesc(xPos, yPos, croppedImg);
    axis image;
    colormap jet;
    cb = colorbar;
    cb.Label.String = 'Intensity (counts)';
    caxis([0 globalMax]);

    title(['Absolute Intensity — ' shortName ' — ' thisView], 'Interpreter','none');
    xlabel('X Position (\mum)');
    ylabel('Y Position (\mum)');

    saveas(fig1, fullfile(fiberDir, ['Abs_' shortName '.png']));
    close(fig1);

    %% =====================================================
    %% PARAMETEREXTRACTIE — DEFINITIEVE SET
    %% =====================================================

    %% Beam widths
    profileX = sum(croppedImg, 1);
    profileX = profileX / max(profileX);
    idxX = find(profileX >= 0.5);
    if numel(idxX) >= 2
        FWHM_x = xPos(idxX(end)) - xPos(idxX(1));
    else
        FWHM_x = NaN;
    end

    profileY = sum(croppedImg, 2);
    profileY = profileY / max(profileY);
    idxY = find(profileY >= 0.5);
    if numel(idxY) >= 2
        FWHM_y = yPos(idxY(end)) - yPos(idxY(1));
    else
        FWHM_y = NaN;
    end

    %% dB beeld
    img_dB = 10 * log10((croppedImg + eps) / globalMax);

    %% ROBUUSTE AREA-BEREKENING
    mask100 = (img_dB >= 0);
    area_100pct = sum(mask100(:)) * pixelSize^2;

    mask75 = (img_dB >= -1.25);
    area_75pct = sum(mask75(:)) * pixelSize^2;

    mask50 = (img_dB >= -3.01);
    area_50pct = sum(mask50(:)) * pixelSize^2;

    mask25 = (img_dB >= -6.02);
    area_25pct = sum(mask25(:)) * pixelSize^2;

    mask5 = (img_dB >= -13.01);
    area_5pct = sum(mask5(:)) * pixelSize^2;

    %% Penetrantie (50%)
    idx50 = find(profileY >= 0.5);
    if isempty(idx50)
        lastY = NaN;
    else
        lastY = yPos(idx50(end));
    end

    depth50pct  = NaN;
    height50pct = NaN;

    if strcmp(thisView,'side')
        depth50pct = lastY;
    else
        height50pct = lastY;
    end

    %% =====================================================
%% FIGURE 2 — dB + contouren (met grotere assen + legende)
%% =====================================================

grey = [0.85 0.85 0.85];
levels = [0, -1.25, -3.01, -6.02, -13.01];
labels = {'100%','75%','50%','25%','5%'};
colors = [
    0.95 0.95 0.95;
    0.00 0.00 0.00;
    0.20 0.60 1.00;
    0.30 0.85 0.30;
    0.93 0.69 0.13;
];

img_dB_smooth = imgaussfilt(img_dB, 3);

fig2 = figure('Color', grey, 'Visible','off', 'Position',[100 100 1200 800]);
imagesc(xPos, yPos, img_dB);
axis image;
colormap jet;

cb2 = colorbar;
cb2.Color = 'k';
cb2.Label.String = 'Intensity (dB)';
cb2.Label.Color = 'k';
cb2.FontSize = 16;          % grotere ticks op colorbar
cb2.Label.FontSize = 18;    % grotere labeltekst
caxis([-20 0]);

sgtitle(['Iso-Intensity Contours (dB) — ' shortName ' — ' thisView], ...
        'Color','k','FontSize',18,'Interpreter','none');

xlabel('X Position (\mum)','Color','k','FontSize',18);
ylabel('Y Position (\mum)','Color','k','FontSize',18);

ax = gca;
ax.XColor = 'k';
ax.YColor = 'k';
ax.Color  = grey;
ax.FontSize = 16;       % grotere tick labels
ax.LineWidth = 1.2;     % iets dikkere assen
ax.Position(3) = ax.Position(3) * 0.70;

hold on;
hLeg = gobjects(length(levels),1);
for i = 1:length(levels)
    contour(xPos, yPos, img_dB_smooth, [levels(i) levels(i)], ...
            'LineWidth',1.2,'Color',colors(i,:));
    hLeg(i) = plot(NaN,NaN,'-','LineWidth',2,'Color',colors(i,:));
end

lg = legend(hLeg, labels, ...
    'Orientation','vertical', ...
    'TextColor','k','Color',grey,'EdgeColor','k','FontSize',16);  % grotere tekst
lg.Units = 'normalized';
lg.Position = [0.82 0.32 0.15 0.36];
lg.ItemTokenSize = [50, 14];   % grotere lijntjes in legende

hold off;

saveas(fig2, fullfile(fiberDir, ['Contours_' shortName '.png']));
close(fig2);


    %% Opslaan in tabel
    results = [results; table( ...
        string(thisFile), string(thisFiber), thisLambda, depth(k), height(k), ...
        FWHM_x, FWHM_y, ...
        area_100pct, area_75pct, area_50pct, area_25pct, area_5pct, ...
        depth50pct, height50pct ...
    )];

end

%% === Parameters opslaan ===
writetable(results, 'parameters_FINAL_feedback_extra_cam.csv');
disp('Analyse + parameterextractie + figuren voltooid.');
