classdef StartExperiment < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        Menu                    matlab.ui.container.Menu
        menu_create_user        matlab.ui.container.Menu
        menu_load_user          matlab.ui.container.Menu
        Menu_2                  matlab.ui.container.Menu
        menu_upload_data        matlab.ui.container.Menu
        menu_copy_data          matlab.ui.container.Menu
        Panel                   matlab.ui.container.Panel
        set_fix_dur             matlab.ui.control.NumericEditField
        Label_10                matlab.ui.control.Label
        start_fixation          matlab.ui.control.Button
        PTBPanel                matlab.ui.container.Panel
        switch_skip_sync_tests  matlab.ui.control.Switch
        SwitchLabel             matlab.ui.control.Label
        tab_all_tests           matlab.ui.container.TabGroup
        tab_day_one             matlab.ui.container.Tab
        panel_resting1          matlab.ui.container.Panel
        resting1_run1           matlab.ui.control.Button
        resting1_run2           matlab.ui.control.Button
        panel_movie             matlab.ui.container.Panel
        movie_run1              matlab.ui.control.Button
        movie_run2              matlab.ui.control.Button
        movie_run3              matlab.ui.control.Button
        movie_run4              matlab.ui.control.Button
        panel_struct            matlab.ui.container.Panel
        start_struct            matlab.ui.control.Button
        set_struct_dur          matlab.ui.control.NumericEditField
        Label_8                 matlab.ui.control.Label
        tab_day_two             matlab.ui.container.Tab
        panel_resting2          matlab.ui.container.Panel
        resting2_run1           matlab.ui.control.Button
        resting2_run2           matlab.ui.control.Button
        panel_task              matlab.ui.container.Panel
        task_run1               matlab.ui.control.Button
        task_run2               matlab.ui.control.Button
        task_run3               matlab.ui.control.Button
        panel_dti               matlab.ui.container.Panel
        start_dti               matlab.ui.control.Button
        set_dti_dur             matlab.ui.control.NumericEditField
        Label_9                 matlab.ui.control.Label
        panel_user              matlab.ui.container.Panel
        button_modify           matlab.ui.control.Button
        Label_6                 matlab.ui.control.Label
        label_user_dob          matlab.ui.control.Label
        label_user_sex          matlab.ui.control.Label
        Label_3                 matlab.ui.control.Label
        label_user_name         matlab.ui.control.Label
        Label                   matlab.ui.control.Label
        label_user_id           matlab.ui.control.Label
        Label_7                 matlab.ui.control.Label
    end

    
    properties (Access = private)
        % user information
        user 
        user_confirmed = false

        % users and progress history
        users_history
        progress_history

        % progress management
        % session means the first and the second day
        % project means each sub project in each day
        % note each time should complete only one session
        session_active % current ongoing session
        project_active % current ongoing project
        project_progress % completed items for ongoing project
        session_init % initiative session, supposed to be completed

        % ptb parameters
        skip_sync_tests = false
    end
    
    properties (Access = private, Constant)
        % make sure this name is part of the panel
        project_names = ["resting1", "movie", "struct", ...
            "resting2", "task", "dti"]
        project_runs = [2, 4, 1, 2, 3, 1]
        sessions = [3, 3];

        % data files (csv format)
        progress_file = fullfile(".db", "progress.txt")
        user_file = fullfile(".db", "user.txt")
    end
    
    methods (Access = public)

        function push_user(app, user)
            app.user = user;
            app.label_user_id.Text = sprintf('%d', app.user.id);
            app.label_user_name.Text = app.user.name;
            app.label_user_sex.Text = app.user.sex;
            app.label_user_dob.Text = string(app.user.dob, 'yyyy-MM-dd');
            if user.id ~= 0
                app.log_user()
            end
        end

        function register_user(app, user)
            app.push_user(user)
            app.user_confirmed = true;
            app.proceed_next()
        end
        
        function update_user(app, user)
            app.push_user(user)
        end

        function load_user(app, user)
            app.initialize()
            % remove current user from users history
            app.users_history(app.users_history.id == user.id, :) = [];
            app.push_user(user)
            app.user_confirmed = true;

            % update progress
            progress = app.progress_history(app.progress_history.user_id == user.id, :);
            app.project_active = progress.project_active;
            app.project_progress = progress.project_progress;
            app.session_active = progress.session_active;
            app.session_init = progress.session_active;

            % update ui
            for i = 1:app.project_active - 1
                panel_project = app.("panel_" + app.project_names(i));
                panel_project.Enable = "on";
                for btn = panel_project.Children'
                    btn.Enable = "off";
                end
            end
            panel_active = app.("panel_" + app.project_names(app.project_active));
            panel_active.Enable = "on";
            btns_active = panel_active.Children';
            for i = 1:app.project_progress
                btns_active(i).Enable = "off";
            end
        end

        function log_progress(app)
            progress = table( ...
                app.user.id, app.session_active, app.project_active, app.project_progress, ...
                'VariableNames', ...
                ["user_id", "session_active", "project_active", "project_progress"]);
            if ~isempty(app.progress_history)
                app.progress_history(app.progress_history.user_id == app.user.id, :) = [];
            end
            app.progress_history = vertcat(app.progress_history, progress);
            writetable(app.progress_history, app.progress_file)
        end

        function log_user(app)
            writetable( ...
                vertcat(app.users_history, struct2table(app.user)), ...
                app.user_file)
        end
    end
    
    methods (Access = private)
        
        function initialize(app)
            if exist(app.progress_file, "file")
                app.progress_history = readtable(app.progress_file, "TextType", "string");
            else
                app.progress_history = table();
            end
            if exist(app.user_file, "file")
                app.users_history = readtable(app.user_file, "TextType", "string");
            else
                app.users_history = table();
            end

            % reset everything as factory setting
            app.panel_user.Enable = "on";
            app.button_modify.Enable = "off";
            app.label_user_id.Text = "?????????";
            app.label_user_name.Text = "?????????";
            app.label_user_sex.Text = "?????????";
            app.label_user_dob.Text = "?????????";
            app.user_confirmed = false;
            app.session_active = 1;
            app.session_init = 1;
            app.project_active = 0;
            app.project_progress = 0;

            % disable all childrens in test tabs, but enable their children
            tabs = app.tab_all_tests.Children';
            for tab = tabs
                for panel = tab.Children'
                    panel.Enable = "off";
                    for btn = panel.Children'
                        btn.Enable = "on";
                        btn.BackgroundColor = [0.96, 0.96, 0.96];
                    end
                end
            end
        end

        function proceed_next(app)
            if app.project_active ~= 0 
                app.project_progress = app.project_progress + 1;
            end
            if app.project_active == 0 || ...
                    app.project_progress == app.project_runs(app.project_active)
                app.proceed_next_project()
            end
            if app.user.id ~= 0
                % user of id 0 is left for tests
                app.log_progress()
            end
        end

        function proceed_next_project(app)
            % set active session as 0 when all completed            
            if app.project_active == length(app.project_names)
                app.session_active = 0;
                return
            end
            % cumulative completed projects for sessions
            cum_ses_proj = cumsum(app.sessions);
            if app.project_active == cum_ses_proj(app.session_active)
                app.session_active = app.session_active + 1;
            end
            app.project_active = app.project_active + 1;
            app.project_progress = 0;
            app.("panel_" + app.project_names(app.project_active)).Enable = "on";
        end
        
        function check_progress(app, status, exception, component, extra)
            if status == 2
                selection = uiconfirm(app.UIFigure, ...
                    '????????????????????????????????????????????????????????????', ...
                    '??????????????????', ...
                    'Icon', 'warning', ...
                    'Options', {'?????????', '?????????'}, ...
                    'DefaultOption', '?????????');
                is_completed = selection == "?????????";
            else
                is_completed = status == 0;
            end
            if ~is_completed
                component.BackgroundColor = "red";
                if ~isempty(exception)
                    uialert(app.UIFigure, getReport(exception), ...
                        '?????????', 'Interpreter', 'html');
                end
            else
                component.BackgroundColor = "green";
                component.Enable = "off";
                if exist("extra", "var")
                    extra.Enable = "off";
                end
                app.proceed_next()
            end
        end

        function result = check_session_confirm(app)
            result = true;
            if app.user_confirmed && app.session_active == app.session_init
                selection = uiconfirm(app.UIFigure, ...
                    '???????????????????????????????????????????????????????????????', ...
                    '??????????????????', ...
                    'Icon', 'warning', ...
                    'Options', {'??????????????????', '??????'});
                if selection == "??????????????????"
                    result = false;
                end
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.initialize()
            app.switch_skip_sync_tests.Value = "??????";
        end

        % Menu selected function: menu_create_user
        function menu_create_userSelected(app, event)
            if ~app.check_session_confirm()
                return
            end
            app.initialize()
            % disable whole user panel when editing user
            app.panel_user.Enable = "off";
            CreateOrModifyUser(app, "create", app.users_history);
        end

        % Button pushed function: button_modify
        function button_modifyButtonPushed(app, event)
            % disable whole user panel when editing user
            app.panel_user.Enable = "off";
            CreateOrModifyUser(app, "modify", app.user);
        end

        % Menu selected function: menu_load_user
        function menu_load_userMenuSelected(app, event)
            if isempty(app.users_history)
                uialert(app.UIFigure, '????????????????????????????????????????????????', ...
                    '????????????', 'Icon', 'warning')
                return
            end
            if ~app.check_session_confirm()
                return
            end
            app.initialize()
            % disable whole user panel when editing user
            app.panel_user.Enable = "off";
            LoadUser(app, app.users_history, app.progress_history);
        end

        % Value changed function: switch_skip_sync_tests
        function switch_skip_sync_testsValueChanged(app, event)
            switch app.switch_skip_sync_tests.Value
                case "??????"
                    app.skip_sync_tests = true;
                case "??????"
                    app.skip_sync_tests = false;
            end
        end

        % Button pushed function: resting1_run1
        function resting1_run1ValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", 7.5, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: resting1_run2
        function resting1_run2ValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", 7.5, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: movie_run1
        function movie_run1ValueChanged(app, event)
            [status, exception] = exp.start_movie(1, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: movie_run2
        function movie_run2ValueChanged(app, event)
            [status, exception] = exp.start_movie(2, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: movie_run3
        function movie_run3ValueChanged(app, event)
            [status, exception] = exp.start_movie(3, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: movie_run4
        function movie_run4ValueChanged(app, event)
            [status, exception] = exp.start_movie(4, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: start_struct
        function start_structValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", app.set_struct_dur.Value, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source, app.set_struct_dur)
        end

        % Button pushed function: resting2_run1
        function resting2_run1ValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", 7.5, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: resting2_run2
        function resting2_run2ValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", 7.5, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: task_run1
        function task_run1ValueChanged(app, event)
            [status, exception] = exp.start_twoback("test", 1, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: task_run2
        function task_run2ValueChanged(app, event)
            [status, exception] = exp.start_twoback("test", 2, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: task_run3
        function task_run3ValueChanged(app, event)
            [status, exception] = exp.start_twoback("test", 3, "id", app.user.id, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source)
        end

        % Button pushed function: start_dti
        function start_dtiValueChanged(app, event)
            [status, exception] = exp.start_fixation("Duration", app.set_dti_dur.Value, "SkipSyncTests", app.skip_sync_tests);
            app.check_progress(status, exception, event.Source, app.set_dti_dur)
        end

        % Button pushed function: start_fixation
        function start_fixationButtonPushed(app, event)
            [status, exception] = exp.start_fixation("Duration", app.set_fix_dur.Value, "SkipSyncTests", app.skip_sync_tests);
            if status ~= 0
                event.Source.BackgroundColor = "red";
            else
                event.Source.BackgroundColor = "green";
            end
            if ~isempty(exception)
                uialert(app.UIFigure, getReport(exception), ...
                    '?????????', 'Interpreter', 'html');
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if ~app.check_session_confirm()
                return
            end
            delete(app)
        end

        % Menu selected function: menu_copy_data
        function menu_copy_dataSelected(app, event)
            dest = uigetdir();
            if dest == 0 
                return
            end
            if strcmp(dest, pwd)
                uialert(app.UIFigure, '??????????????????????????????????????????????????????', ...
                    '????????????', 'Icon', 'warning')
                return
            end
            outfile = fullfile(dest, ...
                sprintf('wm-fmri-%s.zip', ...
                datetime("now", "Format", "yyyyMMdd_HHmmss")));
            try
                zip(outfile, {'.db', 'data'})
                uialert(app.UIFigure, sprintf('?????????????????????%s', outfile), ...
                    '????????????', 'Icon', 'success')
            catch exception
                uialert(app.UIFigure, getReport(exception), ...
                        '????????????', 'Interpreter', 'html');
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 800 500];
            app.UIFigure.Name = '???????????????';
            app.UIFigure.Icon = 'logo.png';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create Menu
            app.Menu = uimenu(app.UIFigure);
            app.Menu.Text = '??????';

            % Create menu_create_user
            app.menu_create_user = uimenu(app.Menu);
            app.menu_create_user.MenuSelectedFcn = createCallbackFcn(app, @menu_create_userSelected, true);
            app.menu_create_user.Accelerator = 'N';
            app.menu_create_user.Text = '??????';

            % Create menu_load_user
            app.menu_load_user = uimenu(app.Menu);
            app.menu_load_user.MenuSelectedFcn = createCallbackFcn(app, @menu_load_userMenuSelected, true);
            app.menu_load_user.Accelerator = 'L';
            app.menu_load_user.Text = '??????';

            % Create Menu_2
            app.Menu_2 = uimenu(app.UIFigure);
            app.Menu_2.Text = '??????';

            % Create menu_upload_data
            app.menu_upload_data = uimenu(app.Menu_2);
            app.menu_upload_data.Text = '??????';

            % Create menu_copy_data
            app.menu_copy_data = uimenu(app.Menu_2);
            app.menu_copy_data.MenuSelectedFcn = createCallbackFcn(app, @menu_copy_dataSelected, true);
            app.menu_copy_data.Text = '?????????...';

            % Create panel_user
            app.panel_user = uipanel(app.UIFigure);
            app.panel_user.TitlePosition = 'centertop';
            app.panel_user.Title = '????????????';
            app.panel_user.FontName = 'Microsoft YaHei UI';
            app.panel_user.FontSize = 16;
            app.panel_user.Position = [53 266 250 215];

            % Create Label_7
            app.Label_7 = uilabel(app.panel_user);
            app.Label_7.FontName = 'Microsoft YaHei UI';
            app.Label_7.Position = [55 148 29 22];
            app.Label_7.Text = '??????';

            % Create label_user_id
            app.label_user_id = uilabel(app.panel_user);
            app.label_user_id.HorizontalAlignment = 'center';
            app.label_user_id.FontName = 'Microsoft YaHei UI';
            app.label_user_id.Position = [134 148 41 22];
            app.label_user_id.Text = '?????????';

            % Create Label
            app.Label = uilabel(app.panel_user);
            app.Label.FontName = 'Microsoft YaHei UI';
            app.Label.Position = [55 114 29 22];
            app.Label.Text = '??????';

            % Create label_user_name
            app.label_user_name = uilabel(app.panel_user);
            app.label_user_name.HorizontalAlignment = 'center';
            app.label_user_name.FontName = 'Microsoft YaHei UI';
            app.label_user_name.Position = [134 114 41 22];
            app.label_user_name.Text = '?????????';

            % Create Label_3
            app.Label_3 = uilabel(app.panel_user);
            app.Label_3.FontName = 'Microsoft YaHei UI';
            app.Label_3.Position = [55 80 29 22];
            app.Label_3.Text = '??????';

            % Create label_user_sex
            app.label_user_sex = uilabel(app.panel_user);
            app.label_user_sex.HorizontalAlignment = 'center';
            app.label_user_sex.FontName = 'Microsoft YaHei UI';
            app.label_user_sex.Position = [134 80 41 22];
            app.label_user_sex.Text = '?????????';

            % Create label_user_dob
            app.label_user_dob = uilabel(app.panel_user);
            app.label_user_dob.HorizontalAlignment = 'center';
            app.label_user_dob.FontName = 'Microsoft YaHei UI';
            app.label_user_dob.Position = [117 46 76 22];
            app.label_user_dob.Text = '?????????';

            % Create Label_6
            app.Label_6 = uilabel(app.panel_user);
            app.Label_6.FontName = 'Microsoft YaHei UI';
            app.Label_6.Position = [55 47 29 22];
            app.Label_6.Text = '??????';

            % Create button_modify
            app.button_modify = uibutton(app.panel_user, 'push');
            app.button_modify.ButtonPushedFcn = createCallbackFcn(app, @button_modifyButtonPushed, true);
            app.button_modify.Tooltip = {'????????????????????????????????????????????????????????????'};
            app.button_modify.Position = [84 15 63 23];
            app.button_modify.Text = '????????????';

            % Create tab_all_tests
            app.tab_all_tests = uitabgroup(app.UIFigure);
            app.tab_all_tests.Position = [357 24 406 457];

            % Create tab_day_one
            app.tab_day_one = uitab(app.tab_all_tests);
            app.tab_day_one.Title = '?????????';

            % Create panel_struct
            app.panel_struct = uipanel(app.tab_day_one);
            app.panel_struct.TitlePosition = 'centertop';
            app.panel_struct.Title = '?????????';
            app.panel_struct.FontName = 'Microsoft YaHei UI';
            app.panel_struct.FontSize = 16;
            app.panel_struct.Position = [73 14 260 104];

            % Create Label_8
            app.Label_8 = uilabel(app.panel_struct);
            app.Label_8.HorizontalAlignment = 'right';
            app.Label_8.Position = [57 11 77 22];
            app.Label_8.Text = '??????????????????';

            % Create set_struct_dur
            app.set_struct_dur = uieditfield(app.panel_struct, 'numeric');
            app.set_struct_dur.Position = [149 11 55 22];
            app.set_struct_dur.Value = 7.5;

            % Create start_struct
            app.start_struct = uibutton(app.panel_struct, 'push');
            app.start_struct.ButtonPushedFcn = createCallbackFcn(app, @start_structValueChanged, true);
            app.start_struct.Position = [84 45 100 23];
            app.start_struct.Text = '??????';

            % Create panel_movie
            app.panel_movie = uipanel(app.tab_day_one);
            app.panel_movie.TitlePosition = 'centertop';
            app.panel_movie.Title = '????????????';
            app.panel_movie.FontName = 'Microsoft YaHei UI';
            app.panel_movie.FontSize = 16;
            app.panel_movie.Position = [74 139 260 141];

            % Create movie_run4
            app.movie_run4 = uibutton(app.panel_movie, 'push');
            app.movie_run4.ButtonPushedFcn = createCallbackFcn(app, @movie_run4ValueChanged, true);
            app.movie_run4.Position = [144 28 66 23];
            app.movie_run4.Text = '?????????';

            % Create movie_run3
            app.movie_run3 = uibutton(app.panel_movie, 'push');
            app.movie_run3.ButtonPushedFcn = createCallbackFcn(app, @movie_run3ValueChanged, true);
            app.movie_run3.Position = [45 28 66 23];
            app.movie_run3.Text = '?????????';

            % Create movie_run2
            app.movie_run2 = uibutton(app.panel_movie, 'push');
            app.movie_run2.ButtonPushedFcn = createCallbackFcn(app, @movie_run2ValueChanged, true);
            app.movie_run2.Position = [144 70 66 23];
            app.movie_run2.Text = '?????????';

            % Create movie_run1
            app.movie_run1 = uibutton(app.panel_movie, 'push');
            app.movie_run1.ButtonPushedFcn = createCallbackFcn(app, @movie_run1ValueChanged, true);
            app.movie_run1.Position = [45 70 66 23];
            app.movie_run1.Text = '?????????';

            % Create panel_resting1
            app.panel_resting1 = uipanel(app.tab_day_one);
            app.panel_resting1.TitlePosition = 'centertop';
            app.panel_resting1.Title = '?????????-????????????';
            app.panel_resting1.FontName = 'Microsoft YaHei UI';
            app.panel_resting1.FontSize = 16;
            app.panel_resting1.Position = [73 302 260 94];

            % Create resting1_run2
            app.resting1_run2 = uibutton(app.panel_resting1, 'push');
            app.resting1_run2.ButtonPushedFcn = createCallbackFcn(app, @resting1_run2ValueChanged, true);
            app.resting1_run2.Position = [145 20 66 23];
            app.resting1_run2.Text = '?????????';

            % Create resting1_run1
            app.resting1_run1 = uibutton(app.panel_resting1, 'push');
            app.resting1_run1.ButtonPushedFcn = createCallbackFcn(app, @resting1_run1ValueChanged, true);
            app.resting1_run1.Position = [46 20 66 23];
            app.resting1_run1.Text = '?????????';

            % Create tab_day_two
            app.tab_day_two = uitab(app.tab_all_tests);
            app.tab_day_two.Title = '?????????';

            % Create panel_dti
            app.panel_dti = uipanel(app.tab_day_two);
            app.panel_dti.TitlePosition = 'centertop';
            app.panel_dti.Title = '??????????????????DTI???';
            app.panel_dti.FontName = 'Microsoft YaHei UI';
            app.panel_dti.FontSize = 16;
            app.panel_dti.Position = [74 24 260 94];

            % Create Label_9
            app.Label_9 = uilabel(app.panel_dti);
            app.Label_9.HorizontalAlignment = 'right';
            app.Label_9.Position = [59 9 77 22];
            app.Label_9.Text = '??????????????????';

            % Create set_dti_dur
            app.set_dti_dur = uieditfield(app.panel_dti, 'numeric');
            app.set_dti_dur.Position = [151 9 55 22];
            app.set_dti_dur.Value = 7.5;

            % Create start_dti
            app.start_dti = uibutton(app.panel_dti, 'push');
            app.start_dti.ButtonPushedFcn = createCallbackFcn(app, @start_dtiValueChanged, true);
            app.start_dti.Position = [83 35 100 23];
            app.start_dti.Text = '??????';

            % Create panel_task
            app.panel_task = uipanel(app.tab_day_two);
            app.panel_task.TitlePosition = 'centertop';
            app.panel_task.Title = '????????????????????????';
            app.panel_task.FontName = 'Microsoft YaHei UI';
            app.panel_task.FontSize = 16;
            app.panel_task.Position = [74 139 260 141];

            % Create task_run3
            app.task_run3 = uibutton(app.panel_task, 'push');
            app.task_run3.ButtonPushedFcn = createCallbackFcn(app, @task_run3ValueChanged, true);
            app.task_run3.Position = [97 23 66 23];
            app.task_run3.Text = '?????????';

            % Create task_run2
            app.task_run2 = uibutton(app.panel_task, 'push');
            app.task_run2.ButtonPushedFcn = createCallbackFcn(app, @task_run2ValueChanged, true);
            app.task_run2.Position = [143 70 66 23];
            app.task_run2.Text = '?????????';

            % Create task_run1
            app.task_run1 = uibutton(app.panel_task, 'push');
            app.task_run1.ButtonPushedFcn = createCallbackFcn(app, @task_run1ValueChanged, true);
            app.task_run1.Position = [44 70 66 23];
            app.task_run1.Text = '?????????';

            % Create panel_resting2
            app.panel_resting2 = uipanel(app.tab_day_two);
            app.panel_resting2.TitlePosition = 'centertop';
            app.panel_resting2.Title = '?????????-????????????';
            app.panel_resting2.FontName = 'Microsoft YaHei UI';
            app.panel_resting2.FontSize = 16;
            app.panel_resting2.Position = [74 302 260 94];

            % Create resting2_run2
            app.resting2_run2 = uibutton(app.panel_resting2, 'push');
            app.resting2_run2.ButtonPushedFcn = createCallbackFcn(app, @resting2_run2ValueChanged, true);
            app.resting2_run2.Position = [143 20 66 23];
            app.resting2_run2.Text = '?????????';

            % Create resting2_run1
            app.resting2_run1 = uibutton(app.panel_resting2, 'push');
            app.resting2_run1.ButtonPushedFcn = createCallbackFcn(app, @resting2_run1ValueChanged, true);
            app.resting2_run1.Position = [44 20 66 23];
            app.resting2_run1.Text = '?????????';

            % Create PTBPanel
            app.PTBPanel = uipanel(app.UIFigure);
            app.PTBPanel.TitlePosition = 'centertop';
            app.PTBPanel.Title = 'PTB??????';
            app.PTBPanel.FontName = 'Microsoft YaHei UI';
            app.PTBPanel.FontSize = 16;
            app.PTBPanel.Position = [53 141 250 112];

            % Create SwitchLabel
            app.SwitchLabel = uilabel(app.PTBPanel);
            app.SwitchLabel.HorizontalAlignment = 'center';
            app.SwitchLabel.Tooltip = {'????????????????????????????????????????????????????????????????????????????????????'};
            app.SwitchLabel.Position = [77 16 77 22];
            app.SwitchLabel.Text = '??????????????????';

            % Create switch_skip_sync_tests
            app.switch_skip_sync_tests = uiswitch(app.PTBPanel, 'slider');
            app.switch_skip_sync_tests.Items = {'??????', '??????'};
            app.switch_skip_sync_tests.ValueChangedFcn = createCallbackFcn(app, @switch_skip_sync_testsValueChanged, true);
            app.switch_skip_sync_tests.Position = [92 53 45 20];
            app.switch_skip_sync_tests.Value = '??????';

            % Create Panel
            app.Panel = uipanel(app.UIFigure);
            app.Panel.TitlePosition = 'centertop';
            app.Panel.Title = '??????';
            app.Panel.FontName = 'Microsoft YaHei UI';
            app.Panel.FontSize = 16;
            app.Panel.Position = [53 25 250 107];

            % Create start_fixation
            app.start_fixation = uibutton(app.Panel, 'push');
            app.start_fixation.ButtonPushedFcn = createCallbackFcn(app, @start_fixationButtonPushed, true);
            app.start_fixation.Position = [74 47 100 23];
            app.start_fixation.Text = '???????????????';

            % Create Label_10
            app.Label_10 = uilabel(app.Panel);
            app.Label_10.HorizontalAlignment = 'right';
            app.Label_10.Position = [51 13 77 22];
            app.Label_10.Text = '??????????????????';

            % Create set_fix_dur
            app.set_fix_dur = uieditfield(app.Panel, 'numeric');
            app.set_fix_dur.Limits = [0 Inf];
            app.set_fix_dur.Position = [143 13 55 22];
            app.set_fix_dur.Value = 7.5;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = StartExperiment

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end