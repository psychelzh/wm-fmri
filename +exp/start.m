function [recordings, status, exception] = start(task_config, id)
%START_NBACK Starts stimuli presentation for n-back test
%   Detailed explanation goes here
arguments
    task_config {mustBeTextScalar, mustBeMember(task_config, ["prac_nback", "prac_manip", "prac", "test"])} = "prac_nback"
    id (1, 1) {mustBeInteger, mustBeNonnegative} = 0
end

import exp.init_config

% ---- set default error related outputs ----
status = 0;
exception = [];

% ---- set experiment timing parameters (predefined here, all in secs) ----
timing = struct( ...
    'nback_stim_secs', 1, ...
    'nback_blank_secs', 1.5, ...
    'manip_encoding_secs', 3, ...
    'manip_cue_secs', 3, ...
    'manip_probe_secs', 1, ...
    'manip_blank_secs', 1.5, ...
    'block_cue_secs', 2, ...
    'feedback_secs', 0.5, ...
    'wait_start_secs', 2);

% ----prepare config and data recording table ----
config = init_config(task_config, timing, id);
recordings = addvars(config, ...
    nan(height(config), 1), cell(height(config), 1), ...
    NewVariableNames={'block_onset_real', 'trials_rec'});

% ---- configure screen and window ----
% setup default level of 2
PsychDefaultSetup(2);
% screen selection
screen_to_display = max(Screen('Screens'));
% set the start up screen to black
old_visdb = Screen('Preference', 'VisualDebugLevel', 1);
% do not skip synchronization test to make sure timing is accurate
old_sync = Screen('Preference', 'SkipSyncTests', 0);
% use FTGL text plugin
old_text_render = Screen('Preference', 'TextRenderer', 1);
% set priority to the top
old_pri = Priority(MaxPriority(screen_to_display));
% PsychDebugWindowConfiguration([], 0.1);

% ---- keyboard settings ----
keys.start = KbName('s');
keys.exit = KbName('Escape');
keys.left = KbName('LeftArrow');
keys.right = KbName('RightArrow');

% ---- stimuli presentation ----
try
    % open a window and set its background color as gray
    gray = WhiteIndex(screen_to_display) / 2;
    [window_ptr, window_rect] = PsychImaging('OpenWindow', screen_to_display, gray);
    % disable character input and hide mouse cursor
    ListenChar(2);
    HideCursor;
    % set blending function
    Screen('BlendFunction', window_ptr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    % set default font name
    Screen('TextFont', window_ptr, 'SimHei');
    % get inter flip interval
    ifi = Screen('GetFlipInterval', window_ptr);
    % make grid buffer
    [center(1), center(2)] = RectCenter(window_rect);
    square_size = round(0.2 * RectHeight(window_rect));
    width_pen = round(0.005 * RectHeight(window_rect));
    width_halfpen = round(width_pen / 2);
    base_rect = [0, 0, 1, 1];
    [x, y] = meshgrid(-1.5:1:1.5, -1.5:1:1.5);
    grid_coords = round([x(:), y(:)] * square_size) + center;
    buffer_grid = Screen('OpenOffscreenWindow', window_ptr, gray);
    draw_grid(buffer_grid);

    % display welcome screen and wait for a press of 's' to start
    switch task_config
        case "prac_nback"
            instr = '下面我们练习一下“N-back”任务';
        case "prac_manip"
            instr = '下面我们练习一下"表象操作”任务';
        case "prac"
            instr = '下面我们将两种任务合在一起一起练习';
        case "test"
            instr = '下面我们将进行"N-back"任务和"表象操作”任务';
    end
    draw_text_center_at(window_ptr, instr, size=0.03);
    Screen('Flip', window_ptr);
    % the flag to determine if the experiment should exit early
    early_exit = false;
    % here we should detect for a key press and release
    while true
        [resp_timestamp, key_code] = KbStrokeWait(-1);
        if key_code(keys.start)
            start_time = resp_timestamp;
            break
        elseif key_code(keys.exit)
            early_exit = true;
            break
        end
    end
    % TODO: add instruction for practice

    % wait for start
    while true && task_config == "test"
        [~, ~, key_code] = KbCheck(-1);
        if key_code(keys.exit)
            early_exit = true;
            break
        end
        draw_text_center_at(window_ptr, '请稍候...');
        vbl = Screen('Flip', window_ptr);
        if vbl >= start_time + timing.wait_start_secs - 0.5 * ifi
            break
        end
    end
    for block_order = 1:height(config)
        if early_exit
            break
        end
        cur_block = config(block_order, :);
        start_time_block = start_time + cur_block.block_onset;

        % cue for each block: task name and domain
        stim_type_name = char(categorical(cur_block.stim_type, ...
            ["digit", "space"], ["数字", "空间"]));
        switch cur_block.task_name
            case "nback"
                task_disp_name = char(cur_block.task_load + "-Back");
            case "manip"
            otherwise
                error('exp:start:invalid_task_name', ...
                    'Invalid game name! "nback" and "manip" are supported!')
        end
        while true
            [~, ~, key_code] = KbCheck(-1);
            if key_code(keys.exit)
                early_exit = true;
                break
            end
            draw_text_center_at(window_ptr, stim_type_name, ...
                Position=[center(1), center(2) - 0.05 * RectHeight(window_rect)], ...
                Color=get_color('dark orange'));
            draw_text_center_at(window_ptr, task_disp_name, ...
                Position=[center(1), center(2) + 0.05 * RectHeight(window_rect)], ...
                Color=get_color('red'));
            vbl = Screen('Flip', window_ptr);
            if vbl >= start_time_block + timing.block_cue_secs - 0.5 * ifi
                break
            end
            if isnan(recordings.block_onset_real(block_order))
                recordings.block_onset_real(block_order) = vbl - start_time;
            end
        end

        % presenting trials
        cur_block_trials = config.trials{block_order};
        trials_rec = repelem( ...
            table(nan, nan, strings, strings, nan, nan, ...
            VariableNames={'stim_onset_real', 'stim_offset_real', ...
            'resp', 'resp_raw', 'acc', 'rt'}), ...
            height(cur_block_trials), 1);
        switch cur_block.task_name
            case "nback"
                routine_nback()
        end
        recordings.trials_rec{block_order} = trials_rec;
    end
    
catch exception
    status = 1;
end

% --- post presentation jobs
Screen('Close');
sca;
% enable character input and show mouse cursor
ListenChar;
ShowCursor;

% restore preferences
Screen('Preference', 'VisualDebugLevel', old_visdb);
Screen('Preference', 'SkipSyncTests', old_sync);
Screen('Preference', 'TextRenderer', old_text_render);
Priority(old_pri);

if ~isempty(exception)
    rethrow(exception)
end

    function routine_nback()
        for trial_order = 1:height(cur_block_trials)
            if early_exit
                break
            end

            this_trial = cur_block_trials(trial_order, :);

            % configure stimuli info
            stim_loc.coords = grid_coords(this_trial.location, :);
            stim_text.text = num2str(this_trial.number);
            stim_text.color = get_color('blue');

            % present stimuli
            resp_made = false;
            stim_status = 0;
            while true
                [key_pressed, timestamp, key_code] = KbCheck(-1);
                if key_code(keys.exit)
                    early_exit = true;
                    break
                end
                Screen('DrawTexture', window_ptr, buffer_grid);
                if key_pressed
                    if ~resp_made
                        resp_code = key_code;
                        resp_timestamp = timestamp;
                    end
                    resp_made = true;
                end
                if resp_made
                    stim_loc.color = WhiteIndex(window_ptr);
                else
                    stim_loc.color = gray;
                end
                if timestamp < start_time_block + this_trial.stim_offset
                    draw_stimuli(stim_loc, stim_text);
                    vbl = Screen('Flip', window_ptr);
                    if stim_status == 0
                        trials_rec.stim_onset_real(trial_order) = ...
                            vbl - start_time_block;
                        stim_status = 1;
                    end
                else
                    draw_stimuli(stim_loc);
                    vbl = Screen('Flip', window_ptr);
                    if stim_status == 1
                        trials_rec.stim_offset_real(trial_order) = ...
                            vbl - start_time_block;
                        stim_status = 2;
                    end
                end
                if vbl >= start_time_block + this_trial.trial_end - 0.5 * ifi
                    break
                end
            end

            % analyze user's response
            if ~resp_made
                resp_raw = "";
                resp = "none";
                resp_time = 0;
            else
                % use "|" as delimiter for the KeyName of "|" is "\\"
                resp_raw = string(strjoin(cellstr(KbName(resp_code)), '|'));
                if ~resp_code(keys.left) && ~resp_code(keys.right)
                    resp = "neither";
                elseif resp_code(keys.left) && resp_code(keys.right)
                    resp = "both";
                elseif resp_code(keys.left)
                    resp = "left";
                else
                    resp = "right";
                end
                resp_time = resp_timestamp - start_time_block - ...
                    trials_rec.stim_onset_real(trial_order);
            end
            trials_rec.resp(trial_order) = resp;
            trials_rec.resp_raw(trial_order) = resp_raw;
            trials_rec.acc(trial_order) = this_trial.cresp == resp;
            trials_rec.rt(trial_order) = resp_time;

            if task_config == "prac_nback"
                while true
                    [~, ~, key_code] = KbCheck(-1);
                    if key_code(keys.exit)
                        early_exit = true;
                        break
                    end
                    Screen('DrawTexture', window_ptr, buffer_grid);
                    fb_loc.coords = stim_loc.coords;
                    fb_text.color = WhiteIndex(window_ptr);
                    if this_trial.cresp ~= resp
                        fb_loc.color = get_color('red');
                        if resp == "none"
                            fb_text.text = '?';
                        else
                            fb_text.text = '×';
                        end
                    else
                        fb_loc.color = get_color('green');
                        fb_text.text = '√';
                    end
                    draw_stimuli(fb_loc, fb_text);
                    vbl = Screen('Flip', window_ptr);
                    if vbl >= start_time_block + this_trial.trial_end + ...
                            timing.feedback_secs - 0.5 * ifi
                        break
                    end
                end
            end
        end
    end

    function draw_grid(window)
        outer_border = CenterRectOnPoint( ...
            base_rect * (square_size * 4 + width_pen), ...
            center(1), center(2));
        fill_rects = CenterRectOnPoint( ...
            base_rect * (square_size - width_halfpen), ...
            grid_coords(:, 1), grid_coords(:, 2))';
        frame_rects = CenterRectOnPoint( ...
            base_rect * (square_size + width_halfpen), ...
            grid_coords(:, 1), grid_coords(:, 2))';
        Screen('FrameRect', window, WhiteIndex(window_ptr), ...
            outer_border, width_pen);
        Screen('FrameRect', window, WhiteIndex(window_ptr), ...
            frame_rects, width_pen);
        Screen('FillRect', window, BlackIndex(window_ptr), ...
            fill_rects);
    end

    function draw_stimuli(loc_spec, text_spec)
        rect = CenterRectOnPoint( ...
            base_rect * (square_size - width_halfpen), ...
            loc_spec.coords(1), loc_spec.coords(2));
        % shade the rect and present digit
        Screen('FillRect', window_ptr, loc_spec.color, ...
            rect);
        if nargin >= 2
            draw_text_center_at(window_ptr, text_spec.text, ...
                Position=loc_spec.coords, Color=text_spec.color);
        end
    end
end

function draw_text_center_at(w, string, opts)
%DRAW_TEXT_CENTER_AT Better control text position.
%
% Input: 
%   w: Window pointer
%   string: The text to draw. Must be scalar text.
%   Name-value pairs:
%       Position: the position to draw text.
%       Color: the text color.
%       Size: the text size.
arguments
    w
    string {mustBeTextScalar}
    opts.Position = "center"
    opts.Color = BlackIndex(w)
    opts.Size = 0.06
end

% DrawText only accept char type
string = double(char(string));
window_rect = Screen('Rect', w);
size = opts.Size;
color = opts.Color;
if isequal(opts.Position, "center")
    [x, y] = RectCenter(window_rect);
else
    x = opts.Position(1);
    y = opts.Position(2);
end
Screen('TextSize', w, round(size * RectHeight(window_rect)));
text_bounds = Screen('TextBounds', w, string);
Screen('DrawText', w, string, ...
    x - round(text_bounds(3) / 2), ...
    y - round(text_bounds(4) / 2), ...
    color);
end