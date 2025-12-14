function sailingGame()
    % Sailing Game 30x30 UI (game logic + UI only)
    % Expects buildMaps_30x30() defined below (do NOT modify it here).
    %
    % Features:
    % - Map selector
    % - 6 headings: 0, 60, 120, 180, 240, 300  (0 = up)
    % - Upwind no-go: 30° from wind-FROM
    % - Boat speed from polar vs wind-FROM
    % - Turn penalties
    % - Time accumulation
    % - Big local-wind arrow for current cell
    % - Export Run → PNG snapshot (map + trace + time)
    % - Load Moves → auto-run from file using same rules

    NO_GO_ANGLE = 30;   % degrees from wind-from
    BASE_TIME   = 10;   % time scaling

    maps = buildMaps_30x30();
    currentMapIndex = 1;

    % Shared state & handles
    windSpeed = [];
    windDir   = [];      % TO direction (map generator)
    startPos  = [];
    finishPos = [];
    state     = struct();

    % Graphics/UI handles
    ax = [];
    heatImg = [];
    quivHandles = [];
    finishPatch = [];
    finishRect = [];
    finishFlag = [];
    cellHighlight = [];
    boatPlot = [];
    pathLine = [];
    buttonHandles = [];
    mapLabel = [];
    statusText = [];
    headingText = [];
    windInfoText = [];
    finishText = [];
    timeText = [];
    resultText = [];
    mapSelect = [];
    windIndicatorAx = [];
    windIndicatorArrow = [];
    exportBtn = [];
    loadBtn = [];

    %% FIGURE & MAIN AXES
    fig = figure('Name','Sailing Game 30x30',...
                 'NumberTitle','off',...
                 'MenuBar','none',...
                 'ToolBar','none',...
                 'Color',[0.15 0.17 0.22],...
                 'Position',[200 100 1100 850]);

    ax = axes('Parent',fig,'Position',[0.05 0.05 0.65 0.90]);
    hold(ax,'on');
    axis(ax,'ij'); axis(ax,'equal');
    grid(ax,'on'); box(ax,'on');
    ax.XColor = [0.8 0.8 0.9];
    ax.YColor = [0.8 0.8 0.9];
    ax.GridColor = [0.1 0.1 0.1];
    ax.GridAlpha = 0.15;
    set(ax,'DataAspectRatio',[1 1 1]);

    %% SIDE PANEL
    panel = uipanel('Parent',fig,...
        'Title','Controls & Status',...
        'FontSize',11,...
        'ForegroundColor',[0.9 0.9 0.9],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'Position',[0.72 0.05 0.25 0.90]);

    % Map selector label
    uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.94 0.40 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.8 0.8 0.9],...
        'FontSize',9,'HorizontalAlignment','left',...
        'String','Select map:');

    % Map selector dropdown
    mapNames = arrayfun(@(m)char(m.name), maps, 'UniformOutput', false);
    mapSelect = uicontrol('Parent',panel,'Style','popupmenu','Units','normalized',...
        'Position',[0.50 0.94 0.42 0.05],...
        'BackgroundColor',[0.18 0.20 0.24],...
        'ForegroundColor',[0.9 0.9 0.9],...
        'FontSize',9,...
        'String',mapNames,...
        'Callback',@(~,~)switchMap());

    % Info labels
    mapLabel = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.88 0.84 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.9 0.9 1.0],...
        'FontSize',10,'HorizontalAlignment','left',...
        'String','Map: -');

    statusText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.82 0.84 0.06],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.95 0.95 0.95],...
        'FontSize',11,'HorizontalAlignment','left',...
        'String','Current cell: -');

    headingText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.76 0.84 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.75 0.75 0.8],...
        'FontSize',10,'HorizontalAlignment','left',...
        'String','Heading: none');

    windInfoText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.70 0.84 0.06],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.7 0.9 0.9],...
        'FontSize',9,'HorizontalAlignment','left',...
        'String','Wind: -');

    finishText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.64 0.84 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.7 0.9 0.7],...
        'FontSize',9,'HorizontalAlignment','left',...
        'String','Finish: -');

    uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.58 0.84 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.7 0.7 0.75],...
        'FontSize',9,'HorizontalAlignment','left',...
        'String','No-go: within 30° of wind-from (opposite arrow).');

    timeText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.50 0.84 0.06],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.95 0.85 0.3],...
        'FontSize',11,'HorizontalAlignment','left',...
        'String','Time: 0.00');

    resultText = uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.08 0.44 0.84 0.05],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.9 0.6 0.4],...
        'FontSize',10,'HorizontalAlignment','left',...
        'String','Status: In progress');

    %% EXPORT / LOAD BUTTONS

    exportBtn = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[0.08 0.38 0.38 0.05],...
        'BackgroundColor',[0.18 0.20 0.24],...
        'ForegroundColor',[0.9 0.9 0.9],...
        'FontSize',9,...
        'String','Export Run (PNG)',...
        'Callback',@(~,~)exportRun());

    loadBtn = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[0.54 0.38 0.38 0.05],...
        'BackgroundColor',[0.18 0.20 0.24],...
        'ForegroundColor',[0.9 0.9 0.9],...
        'FontSize',9,...
        'String','Load Moves (auto)',...
        'Callback',@(~,~)loadMoves());

    %% LOCAL WIND INDICATOR (BIG ARROW)

    uicontrol('Parent',panel,'Style','text','Units','normalized',...
        'Position',[0.18 0.23 0.64 0.04],...
        'BackgroundColor',[0.12 0.14 0.18],...
        'ForegroundColor',[0.8 0.9 1.0],...
        'FontSize',9,'HorizontalAlignment','center',...
        'String','Local wind at current cell');

    windIndicatorAx = axes('Parent',panel,...
        'Units','normalized',...
        'Position',[0.30 0.12 0.40 0.08],...
        'Color','none');
    axis(windIndicatorAx,'off');
    axis(windIndicatorAx,'equal');
    axis(windIndicatorAx,'ij');
    xlim(windIndicatorAx,[0 1]);
    ylim(windIndicatorAx,[0 1]);

    %% D-PAD BUTTONS
    btnW = 0.18; btnH = 0.08;
    centerX = 0.5; topY = 0.2; midY = 0.16; botY = 0.05; dx = 0.22;

    btnN = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX-btnW/2, topY, btnW, btnH],...
        'String','↑ N','FontSize',10,...
        'Callback',@(src,evt)moveBoat(0,false));

    btnNE = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX+dx-btnW/2, midY, btnW, btnH],...
        'String','↗ NE','FontSize',10,...
        'Callback',@(src,evt)moveBoat(60,false));

    btnNW = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX-dx-btnW/2, midY, btnW, btnH],...
        'String','↖ NW','FontSize',10,...
        'Callback',@(src,evt)moveBoat(300,false));

    btnS = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX-btnW/2, botY, btnW, btnH],...
        'String','↓ S','FontSize',10,...
        'Callback',@(src,evt)moveBoat(180,false));

    btnSE = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX+dx-btnW/2, botY, btnW, btnH],...
        'String','↘ SE','FontSize',10,...
        'Callback',@(src,evt)moveBoat(120,false));

    btnSW = uicontrol('Parent',panel,'Style','pushbutton','Units','normalized',...
        'Position',[centerX-dx-btnW/2, botY, btnW, btnH],...
        'String','↙ SW','FontSize',10,...
        'Callback',@(src,evt)moveBoat(240,false));

    buttonHandles = [btnN, btnNE, btnNW, btnS, btnSE, btnSW];

    %% INITIAL MAP LOAD
    loadMap(currentMapIndex);

    %% ==== CALLBACKS & HELPERS ====

    function switchMap()
        idx = get(mapSelect,'Value');
        if idx ~= currentMapIndex
            currentMapIndex = idx;
            loadMap(currentMapIndex);
        end
    end

    function loadMap(idx)
        m = maps(idx);
        windSpeed = m.windSpeed;
        windDir   = m.windDir;   % TO direction
        startPos  = m.startPos;
        finishPos = m.finishPos;

        [Nrows,Ncols] = size(windSpeed);

        cla(ax);
        axis(ax,'ij'); axis(ax,'equal');
        axis(ax,[0.5, Ncols+0.5, 0.5, Nrows+0.5]);
        set(ax,'XTick',1:2:Ncols,'YTick',1:2:Nrows);
        grid(ax,'on'); box(ax,'on');
        set(ax,'DataAspectRatio',[1 1 1]);

        % Heatmap
        heatImg = imagesc(ax, windSpeed);
        colormap(ax, parula);
        colorbar(ax,'peer',ax);
        uistack(heatImg,'bottom');

        % Wind arrows (TO direction, matches headings)
        [Xg,Yg] = meshgrid(1:Ncols,1:Nrows);
        U = sind(windDir);
        V = -cosd(windDir);   % axis ij
        quivHandles = quiver(ax, Xg, Yg, U, V, 0.35, ...
            'Color',[0.85 0.85 0.85], ...
            'LineWidth',0.6, ...
            'MaxHeadSize',2);

        % Finish visuals
        if ~isempty(finishPatch), delete(finishPatch); end
        if ~isempty(finishRect),  delete(finishRect);  end
        if ~isempty(finishFlag),  delete(finishFlag);  end

        fr = finishPos(1); fc = finishPos(2);
        finishPatch = patch(ax,...
            [fc-0.6, fc+0.6, fc+0.6, fc-0.6], ...
            [fr-0.6, fr-0.6, fr+0.6, fr+0.6], ...
            [0.2 1.0 0.2], ...
            'FaceAlpha',0.25, ...
            'EdgeColor',[0.1 0.8 0.1], ...
            'LineWidth',2.0);

        finishRect = rectangle(ax,...
            'Position',[fc-0.6, fr-0.6, 1.2, 1.2],...
            'EdgeColor',[1 1 1],...
            'LineWidth',1.5);

        finishFlag = text(fc, fr, '🏁', ...
            'FontSize',20, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'Color',[1 1 1], ...
            'FontWeight','bold');

        % Reset state
        state.row = startPos(1);
        state.col = startPos(2);
        state.heading = NaN;
        state.path_rows = state.row;
        state.path_cols = state.col;
        state.time = 0;
        state.finished = false;

        % Boat & path
        if ~isempty(cellHighlight), delete(cellHighlight); end
        if ~isempty(boatPlot),      delete(boatPlot);      end
        if ~isempty(pathLine),      delete(pathLine);      end

        cellHighlight = rectangle(ax,...
            'Position',[state.col-0.5, state.row-0.5, 1, 1],...
            'EdgeColor',[1.0 1.0 0.2],...
            'LineWidth',1.5);

        boatPlot = plot(ax, state.col, state.row, '^', ...
            'MarkerSize',14, ...
            'MarkerFaceColor',[0.0 0.2 0.8], ...
            'MarkerEdgeColor',[1 1 1], ...
            'LineWidth',1.0);

        pathLine = plot(ax, state.path_cols, state.path_rows, '-', ...
            'Color',[0.9 0.1 0.1], ...
            'LineWidth',1.8);

        set(buttonHandles,'Enable','on');

        % UI text
        set(mapLabel,'String',sprintf('Map: %s', m.name));
        set(statusText,'String', ...
            sprintf('Current cell: (%d, %d)', state.row, state.col));
        set(headingText,'String','Heading: none');

        w_to   = windDir(state.row,state.col);
        w_from = mod(w_to + 180, 360);
        set(windInfoText,'String', ...
            sprintf('Wind: %.1f, to %d°, from %d°', ...
                windSpeed(state.row,state.col), w_to, w_from));

        set(finishText,'String', ...
            sprintf('Finish: (%d, %d)', finishPos(1), finishPos(2)));
        set(timeText,'String','Time: 0.00');
        set(resultText,'String','Status: In progress');

        % Big arrow
        updateWindIndicator(state.row, state.col);

        drawnow;
    end

    function f = polarFactor(rel_deg)
        % Boat polar vs angle to wind-FROM (after no-go check)
        if rel_deg >= 30 && rel_deg < 60
            f = 1.0;
        elseif rel_deg >= 60 && rel_deg < 90
            f = 0.95;
        elseif rel_deg >= 90 && rel_deg < 135
            f = 0.85;
        elseif rel_deg >= 135 && rel_deg <= 180
            f = 0.70;
        else
            f = 0;
        end
    end

    function tp = turnPenalty(prev_dir, new_dir)
        if isnan(prev_dir)
            tp = 0; return;
        end
        d = abs(prev_dir - new_dir);
        d = min(d, 360 - d);

        if d == 0
            tp = 0;
        elseif d <= 10
            tp = 0.5;
        elseif d <= 20
            tp = 1.0;
        elseif d <= 30
            tp = 1.5;
        elseif d <= 40
            tp = 2.0;
        elseif d <= 50
            tp = 2.5;
        elseif d <= 60
            tp = 3.0;
        else
            tp = 4.0;
        end
    end

function updateWindIndicator(r, c)
    % Big local wind arrow for cell (r,c)
    if isempty(windIndicatorAx) || isempty(windDir)
        return;
    end
    if r < 1 || c < 1 || r > size(windDir,1) || c > size(windDir,2)
        return;
    end

    theta = windDir(r, c);   % TO direction, same as map quiver
    x0 = 0.5; y0 = 0.5; L = 0.30;

    % Same convention as main map:
    % U = sind(theta), V = -cosd(theta), with axis 'ij'
    u = L * sind(theta);
    v = -L * cosd(theta);

    cla(windIndicatorAx);
    axes(windIndicatorAx); %#ok<LAXES>
    hold(windIndicatorAx,'on');
    axis(windIndicatorAx,'off');
    axis(windIndicatorAx,'equal');
    axis(windIndicatorAx,'ij');         % 🔴 ensure same orientation
    xlim(windIndicatorAx,[0 1]);
    ylim(windIndicatorAx,[0 1]);

    quiver(windIndicatorAx, x0, y0, u, v, 0, ...
        'LineWidth',2.0, ...
        'Color',[0.9 0.9 0.9], ...
        'MaxHeadSize',2);

    hold(windIndicatorAx,'off');
end


    function moveBoat(boat_dir, isAuto)
        if nargin < 2
            isAuto = false;
        end

        if state.finished
            return;
        end

        % Local wind (TO and FROM) at current cell
        w_to = windDir(state.row, state.col);
        w_from = mod(w_to + 180, 360);

        % Angle between heading and wind-FROM
        raw = abs(boat_dir - w_from);
        rel = min(raw, 360 - raw);

        % Upwind restriction
        if rel < NO_GO_ANGLE
            if ~isAuto
                set(resultText,'String','Status: Upwind move blocked');
            end
            return;
        end

        % Movement vector
        switch boat_dir
            case 0,   dr = -1; dc =  0;
            case 60,  dr = -1; dc =  1;
            case 120, dr =  1; dc =  1;
            case 180, dr =  1; dc =  0;
            case 240, dr =  1; dc = -1;
            case 300, dr = -1; dc = -1;
            otherwise
                return;
        end

        newRow = state.row + dr;
        newCol = state.col + dc;

        [Nrows, Ncols] = size(windSpeed);
        if newRow < 1 || newRow > Nrows || newCol < 1 || newCol > Ncols
            if ~isAuto
                set(resultText,'String','Status: Edge of map');
            end
            return;
        end

        % Speed factor
        f = polarFactor(rel);
        if f <= 0
            if ~isAuto
                set(resultText,'String','Status: No speed (angle)');
            end
            return;
        end

        w_speed = windSpeed(state.row, state.col);
        boat_speed = w_speed * f;

        % Turn penalty
        tp = turnPenalty(state.heading, boat_dir);

        % Time increment
        move_time = BASE_TIME / boat_speed + tp;

        % Update state
        state.row = newRow;
        state.col = newCol;
        state.heading = boat_dir;
        state.path_rows(end+1) = newRow; %#ok<AGROW>
        state.path_cols(end+1) = newCol; %#ok<AGROW>
        state.time = state.time + move_time;

        % Visuals
        set(boatPlot,'XData',state.col,'YData',state.row);
        set(cellHighlight,'Position',[state.col-0.5, state.row-0.5, 1, 1]);
        set(pathLine,'XData',state.path_cols,'YData',state.path_rows);

    % Text
    set(statusText,'String', ...
        sprintf('Current cell: (%d, %d)', state.row, state.col));
    set(headingText,'String', ...
        sprintf('Heading: %d°', boat_dir));

    % Recompute wind at NEW cell (fixes mismatch)
    w_speed    = windSpeed(state.row, state.col);
    w_to_now   = windDir(state.row, state.col);
    w_from_now = mod(w_to_now + 180, 360);

    set(windInfoText,'String', ...
        sprintf('Wind: %.1f, to %d°, from %d°', ...
            w_speed, w_to_now, w_from_now));

    set(timeText,'String', sprintf('Time: %.2f', state.time));

    % Big arrow now matches this cell
    updateWindIndicator(state.row, state.col);

        % Finish check
        if state.row == finishPos(1) && state.col == finishPos(2)
            state.finished = true;
            if ~isAuto
                set(resultText,'String', ...
                    sprintf('Status: Finished! Time: %.2f', state.time));
            end
            set(buttonHandles,'Enable','off');
        else
            if ~isAuto
                set(resultText,'String','Status: In progress');
            end
        end

        drawnow;
    end

    function exportRun()
        if isempty(state) || isempty(state.path_rows)
            set(resultText,'String','Status: Nothing to export yet');
            return;
        end

        defaultName = sprintf('run_%s_%.2f.png', ...
            maps(currentMapIndex).name, state.time);
        [file, path] = uiputfile('*.png', 'Save run snapshot as', defaultName);
        if isequal(file,0)
            return;
        end
        fullpath = fullfile(path, file);

        try
            % Temporary overlay with map name & time
            overlay = annotation(fig,'textbox',[0.65 0.955 0.33 0.04], ...
                'String',sprintf('Map: %s   Time: %.2f', ...
                    maps(currentMapIndex).name, state.time), ...
                'Color',[1 1 1], ...
                'EdgeColor','none', ...
                'FontSize',9, ...
                'HorizontalAlignment','right', ...
                'BackgroundColor','none');
            drawnow;
            exportgraphics(fig, fullpath, 'Resolution',200);
            delete(overlay);
            set(resultText,'String',sprintf('Status: Run exported: %s', file));
        catch ME
            set(resultText,'String', ...
                sprintf('Status: Export failed (%s)', ME.message));
        end
    end

    function loadMoves()
        [file, path] = uigetfile({'*.txt;*.csv','Move list (*.txt,*.csv)'}, ...
                                 'Select move list to auto-run');
        if isequal(file,0)
            return;
        end
        fullpath = fullfile(path, file);

        dirs = parseMoveFile(fullpath);
        if isempty(dirs)
            set(resultText,'String','Status: No valid moves found in file');
            return;
        end

        % Reset current map
        loadMap(currentMapIndex);

        % Auto-run sequence (no pauses)
        set(buttonHandles,'Enable','off');
        for k = 1:numel(dirs)
            if state.finished
                break;
            end
            moveBoat(dirs(k), true);
        end
        set(buttonHandles,'Enable','on');

        if state.finished
            set(resultText,'String', ...
                sprintf('Status: Auto-run finished. Time: %.2f', state.time));
        else
            set(resultText,'String', ...
                sprintf('Status: Auto-run stopped at (%d,%d), Time: %.2f', ...
                    state.row, state.col, state.time));
        end
    end

    function dirs = parseMoveFile(filename)
        % Accepts:
        % - One move per line: 0,60,120,180,240,300
        % - Or: N, NE, SE, S, SW, NW
        dirs = [];
        try
            txt = fileread(filename);
        catch
            return;
        end

        lines = regexp(txt, '\r\n|\n|\r', 'split');
        for i = 1:numel(lines)
            t = strtrim(lines{i});
            if isempty(t), continue; end

            % Try numeric
            v = str2double(t);
            if ~isnan(v)
                if any(v == [0 60 120 180 240 300])
                    dirs(end+1) = v; %#ok<AGROW>
                end
                continue;
            end

            % Normalise text
            t = upper(regexprep(t,'\s+',''));

            switch t
                case 'N'
                    dirs(end+1) = 0;
                case 'NE'
                    dirs(end+1) = 60;
                case 'SE'
                    dirs(end+1) = 120;
                case 'S'
                    dirs(end+1) = 180;
                case 'SW'
                    dirs(end+1) = 240;
                case 'NW'
                    dirs(end+1) = 300;
                otherwise
                    % ignore invalid token
            end
        end
    end
end

function maps = buildMaps_30x30()

    % Map generator for 3 x 30x30 maps.
    % Assumptions:
    % - Angles use your sailing convention: 0° = up, 90° = right, etc.
    % - windDir is the direction the wind blows TOWARDS (same angle system).
    % - Upwind in your main code is checked against wind-from = windDir + 180.
    %
    % Design:
    % - All maps: wind broadly converges toward start (30,1),
    %   so arrows "lean" into that corner and sailing to the top is mostly upwind.
    % - Map 1: clean, gentle, very readable.
    % - Map 2: stronger structure, fast corridor + soft trap.
    % - Map 3: more complex, subtle lanes, still converging feel.

    N = 30;
    [C,R] = meshgrid(1:N,1:N);
    startPos = [30, 1];  % bottom-left

    maps = struct('name',{},'windSpeed',{},'windDir',{},'startPos',{},'finishPos',{});

    % Helper: base direction TO the start corner (using 0°=up convention)
    % For a vector (dr,dc), heading θ is: dr = -cosθ, dc = sinθ  -> θ = atan2d(dc,-dr)
    dR = startPos(1) - R;
    dC = startPos(2) - C;
    baseDirToStart = atan2d(dC, -dR);           % direction TOWARDS start
    baseDirToStart = mod(round(baseDirToStart/5)*5, 360);  % snap to 5°

    %% ---------- MAP 1: TRAINING ----------
    finishPos = [1, 15];

    % Speed: radial increase away from start (so it "feels" like wind feeding in)
    dist = sqrt(dR.^2 + dC.^2);
    distNorm = dist ./ max(dist(:));
    ws = 3 + 4*distNorm;       % ~3 near start, up to ~7 far away

    % Smooth for realism
    k = [0.05 0.1 0.05; 0.1 0.4 0.1; 0.05 0.1 0.05];
    ws = conv2(ws, k, 'same');
    ws = max(2, min(8, ws));

    % Direction: mostly converging; tiny curl so it’s not perfectly radial
    wd = baseDirToStart ...
         + 5 * sin((C + R) / (2*N) * 2*pi);   % gentle global variation
    wd = mod(round(wd/5)*5, 360);

    maps(1).name      = "Training";
    maps(1).windSpeed = ws;
    maps(1).windDir   = wd;
    maps(1).startPos  = startPos;
    maps(1).finishPos = finishPos;
         %% ---------- MAP 2: MAIN (dual suns, patchy lanes, jump hotspots) ----------
    finishPos = [1, 20];

    % Baseline: gentle increase away from start (converging feel)
    dist = sqrt(dR.^2 + dC.^2);
    distNorm = dist ./ max(dist(:));
    ws = 3 + 3.0 * distNorm;

    k = [0.05 0.10 0.05;
         0.10 0.40 0.10;
         0.05 0.10 0.05];

    %% 1) Primary sun (centre-right)
    v1r = 6;  v1c = 22;
    dx1 = C - v1c;  dy1 = R - v1r;
    rv1 = sqrt(dx1.^2 + dy1.^2);

    core1 = rv1 <= 3.0;
    ring1 = rv1 > 3.0 & rv1 <= 6.0;
    moat1 = rv1 > 6.0 & rv1 <= 9.0 & R > v1r;

    ws(core1) = ws(core1) + 4.0;
    ws(ring1) = ws(ring1) + 2.0;
    ws(moat1) = ws(moat1) - 1.3;

    %% 2) Secondary sun (low-left)
    v3r = 17;  v3c = 7;
    dx3 = C - v3c;  dy3 = R - v3r;
    rv3 = sqrt(dx3.^2 + dy3.^2);

    core3 = rv3 <= 3.0;
    ring3 = rv3 > 3.0 & rv3 <= 6.0;
    moat3 = rv3 > 6.0 & rv3 <= 9.0 & R < v3r + 5;

    ws(core3) = ws(core3) + 3.5;
    ws(ring3) = ws(ring3) + 1.8;
    ws(moat3) = ws(moat3) - 1.0;

    %% 3) Left teardrop eddy
    v2r = 8;  v2c = 5;
    dx2 = C - v2c;  dy2 = R - v2r;
    rv2 = sqrt(dx2.^2 + dy2.^2);

    core2 = rv2 <= 2.2;
    tail2 = rv2 > 2.2 & rv2 <= 8.0 & (R > v2r);
    moat2 = rv2 > 3.0 & rv2 <= 7.0 & (C < v2c);

    ws(core2) = ws(core2) + 2.2;
    ws(tail2) = ws(tail2) + 1.0;
    ws(moat2) = ws(moat2) - 1.0;

    %% 4) Right sweeping corridor (long, patchy)
    centerB = 21 + 2.0 * sin((R-3)/4);
    corridorB = abs(C - centerB) <= 2 ...
                & R >= 6 & R <= 30 ...
                & ~core1 & ~core2 & ~moat1;
    ws(corridorB) = ws(corridorB) + 2.0;
    gustB = corridorB & (mod(R + 2*C,7)==0);
    lullB = corridorB & (mod(R + C,9)==0);
    ws(gustB) = ws(gustB) + 0.8;
    ws(lullB) = ws(lullB) - 0.8;

    %% 5) Left/central corridor (long, patchy)
    centerA = 0.6*(N-R) + 7 + 1.5*sin(R/6);
    corridorA = abs(C - centerA) <= 2 ...
                & R >= 8 & R <= 28 ...
                & ~core1 & ~moat1;
    ws(corridorA) = ws(corridorA) + 1.8;
    gustA = corridorA & (mod(R + 3*C,8)==0);
    lullA = corridorA & (mod(R + C,6)==0);
    ws(gustA) = ws(gustA) + 0.7;
    ws(lullA) = ws(lullA) - 0.7;

    %% 6) Bridge across middle
    bridge = (R >= 7 & R <= 9 & C >= 8 & C <= 20);
    ws(bridge) = ws(bridge) + 0.8;
    ws(bridge & mod(C,4)==0) = ws(bridge & mod(C,4)==0) - 0.5;

    %% 7) Slow pockets (discourage lazy middle)
    hole1 = (R>=11 & R<=14 & C>=16 & C<=20);   % under main sun
    hole2 = (R>=13 & R<=18 & C>=9  & C<=13);   % central dip
    ws(hole1) = ws(hole1) - 1.2;
    ws(hole2) = ws(hole2) - 0.8;

    %% 8) Extra hotspots for "jumping" routes
    % Medium/high-speed islands players can chain together.

    % hotspot 1: mid-left above secondary sun
    hs1 = (R>=10 & R<=12 & C>=6 & C<=8);
    % hotspot 2: mid-centre
    hs2 = (R>=9  & R<=11 & C>=14 & C<=16);
    % hotspot 3: lower-right corridor support
    hs3 = (R>=18 & R<=21 & C>=20 & C<=24);
    % hotspot 4: high-left near bridge
    hs4 = (R>=6  & R<=7  & C>=9  & C<=11);

    ws(hs1) = ws(hs1) + 1.4;
    ws(hs2) = ws(hs2) + 1.6;
    ws(hs3) = ws(hs3) + 1.4;
    ws(hs4) = ws(hs4) + 1.2;

    % ensure hotspots don't override holes too much
    ws(hole1) = ws(hole1) - 0.4;
    ws(hole2) = ws(hole2) - 0.3;

    %% Final smooth & clamp
    ws = conv2(ws, k, 'same');
    ws = max(1.5, min(9.8, ws));

    % ================= Directions =================
    wd = baseDirToStart;   % TO start baseline

    % Primary sun swirl
    toV1 = atan2d(v1c - C, -(v1r - R));  toV1 = mod(toV1,360);
    swirl1 = mod(toV1 + 90,360);
    wd(core1) = swirl1(core1);
    wd(ring1) = blendAngles(wd(ring1), swirl1(ring1), 0.6);
    wd(moat1) = blendAngles(wd(moat1), swirl1(moat1)-30, 0.5);

    % Secondary sun swirl (opposite)
    toV3 = atan2d(v3c - C, -(v3r - R));  toV3 = mod(toV3,360);
    swirl3 = mod(toV3 - 90,360);
    wd(core3) = swirl3(core3);
    wd(ring3) = blendAngles(wd(ring3), swirl3(ring3), 0.6);
    wd(moat3) = blendAngles(wd(moat3), swirl3(moat3)+25, 0.4);

    % Left eddy swirl
    toV2 = atan2d(v2c - C, -(v2r - R));  toV2 = mod(toV2,360);
    swirl2 = mod(toV2 + 90,360);
    wd(core2) = swirl2(core2);
    wd(tail2) = blendAngles(wd(tail2), swirl2(tail2), 0.6);
    wd(moat2) = blendAngles(wd(moat2), swirl2(moat2)-25, 0.5);

    % Corridors + bridge
    wd(corridorB) = blendAngles(wd(corridorB), baseDirToStart(corridorB)+10, 0.7);
    wd(corridorA) = blendAngles(wd(corridorA), baseDirToStart(corridorA),    0.7);
    wd(bridge)    = blendAngles(wd(bridge),    baseDirToStart(bridge),       0.5);

    % Holes: awkward
    wd(hole1) = wd(hole1) + 20;
    wd(hole2) = wd(hole2) - 15;

    % Hotspots: bias toward nice usable angles (encourage hopping)
    hs = hs1 | hs2 | hs3 | hs4;
    wd(hs) = blendAngles(wd(hs), baseDirToStart(hs), 0.6);

    % Organic perturbation
    wd = wd + 4 * sin((C - R)/N * pi);
    wd = mod(round(wd/5)*5, 360);

    maps(2).name      = "Main";
    maps(2).windSpeed = ws;
    maps(2).windDir   = wd;
    maps(2).startPos  = startPos;
    maps(2).finishPos = finishPos;

    %% ---------- MAP 3: TIEBREAKER ----------
    finishPos = [1, 25];

    % Base: converging + noise
    rng(321);  % deterministic
    noise = rand(N);
    noise = conv2(noise, k, 'same');   % smooth noise

    dist = sqrt(dR.^2 + dC.^2);
    distNorm = dist ./ max(dist(:));
    ws = 3 + 4.5*distNorm + 2*(noise - 0.5);   % 3..~9 with texture
    ws = conv2(ws, k, 'same');
    ws = max(1.5, min(9.5, ws));

    % Two subtle "good" lanes:
    lane1 = abs(C - (0.5*(N-R) + 4)) <= 2;
    lane2 = abs(C - (0.3*(N-R) + 15)) <= 2;
    ws(lane1) = ws(lane1) + 1.5;
    ws(lane2) = ws(lane2) + 1.5;
    ws = max(1.5, min(9.5, ws));

    % Directions: converging + swirl + lane bias
    wd = baseDirToStart ...
         + 12 * (noise - 0.5) ...                % local variability
         + 8 * sin((C - R)/N * pi);              % large-scale rotation

    % In lanes, make flow cleaner toward start (reward spotting them)
    wd(lane1) = baseDirToStart(lane1) + 5;
    wd(lane2) = baseDirToStart(lane2) - 5;

    % Edges: a bit more chaotic / hostile
    edgeMask = (C <= 3) | (C >= 28);
    wd(edgeMask) = wd(edgeMask) + 25 * sign(C(edgeMask) - (N/2));

    wd = mod(round(wd/5)*5, 360);

    maps(3).name      = "Tiebreaker";
    maps(3).windSpeed = ws;
    maps(3).windDir   = wd;
    maps(3).startPos  = startPos;
    maps(3).finishPos = finishPos;

    function out = blendAngles(a_deg, b_deg, alpha)
        % Blend angles (deg) along shortest path.
        % a_deg, b_deg: same size; alpha in [0,1].
        diff = mod(b_deg - a_deg + 540, 360) - 180;  % [-180,180]
        out = mod(a_deg + alpha .* diff, 360);
    end
   end