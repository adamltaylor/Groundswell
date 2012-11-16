classdef View < handle

  properties
    controller;  % the controller
    model;  % the model
    
    figure_h;
    colorbar_axes_h;
    colorbar_h;
    image_axes_h;
    image_h;
    
    to_start_button_h;
    play_backward_button_h;
    frame_backward_button_h;
    stop_button_h;
    frame_forward_button_h;
    play_forward_button_h;
    to_end_button_h;
    
    frame_text_h;
    frame_index_edit_h;
    of_n_frames_text_h;
    FPS_text_h;
    FPS_edit_h;
    
    elliptic_roi_button_h;
    rect_roi_button_h;
    polygonal_roi_button_h;
    select_button_h;
    zoom_button_h;
    move_all_button_h;
    
    file_menu_h
    open_video_menu_h
    open_rois_menu_h;
    save_rois_to_file_menu_h;
    export_to_tcs_menu_h
    load_overlay_menu_h
    quit_menu_h
    
    edit_menu_h
    cut_menu_h
    copy_menu_h
    paste_menu_h
    
    color_menu_h;
    pixel_data_type_min_max_menu_h;
    min_max_menu_h;
    five_95_menu_h;
    abs_max_menu_h;
    ninety_symmetric_menu_h;
    colorbar_edit_bounds_menu_h;
    gray_menu_h;
    bone_menu_h;
    hot_menu_h;
    jet_menu_h;
    red_green_menu_h;
    red_blue_menu_h;
    brighten_menu_h;
    darken_menu_h;
    revert_menu_h;
    
    mutation_menu_h;
    motion_correct_menu_h;
    
    rois_menu_h;
    rename_roi_menu_h;
    delete_roi_menu_h;
    delete_all_rois_menu_h;
    hide_rois_menu_h;
    
    overlay_menu_h;
    show_overlay_menu_h;
    
    frame_index;
    % this holds the _playback_ frame rate, in frames/sec
    stop_button_hit;
    % this is the current selection mode
    mode;
    cmap_name;
    % colorbar_min and colorbar_max are constrained to be integers
    colorbar_max_string;  
    colorbar_min_string;
    colorbar_min;  % the colorbar min, derived from cb_min_string, 
                   % dependent in spirit
    colorbar_max;  % the colorbar max, derived from cb_min_string, 
                   % dependent in spirit    
    % roi state
    selected_roi_index;
    hide_rois;
    border_roi_h
    label_roi_h
    
    % in-progress polygonal ROI
    polygonal_roi
    
    % overlay state
    overlay_h;
    show_overlay;
    
    % widget sizes that we want to store internally, for convenience
    frame_text_width
    frame_text_height
    frame_index_edit_width
    frame_index_edit_height
    of_n_frames_text_width
    of_n_frames_text_height
    FPS_text_width
    FPS_text_height
    FPS_edit_width
    FPS_edit_height
  end  % properties
  
  properties (Dependent=true)
    indexed_frame
  end
  
  methods
    function self=View(controller)
      % We keep a reference to the controller, but use it only to set
      % widget callbacks.
      self.controller=controller;
      self.model=[];  % No model yet.

      % Set defaults
      cmap_name='gray';
      
      % get the screen size so we can position the figure window
      root_units=get(0,'Units');
      set(0,'Units','pixels');
      screen_dims=get(0,'ScreenSize');
      %screen_width=screen_dims(3);
      screen_height=screen_dims(4);
      set(0,'Units',root_units);

      %
      % spec out the initial size, position of the figure
      %
            
      screen_left_pad_size=20;
      screen_top_pad_size=50;
      % these are designed to just accomodate a 512x512 image
      figure_width=722;  
      figure_height=602;

      % minimum figure dimensions
      figure_width_min=600;  % pels
      figure_height_min=400;

      %
      % Image figure and children
      %

      % create the image figure
      self.figure_h = ...
        figure('Position', ...
                 [screen_left_pad_size, ...
                  screen_height-figure_height-screen_top_pad_size+1, ...
                  figure_width, ...
                  figure_height], ...
               'Name','Roving',...
               'NumberTitle','off',...
               'Colormap',eval(sprintf('%s(256)',cmap_name)),...
               'MenuBar','none',...
               'PaperPositionMode','auto',...
               'InvertHardcopy','off',...
               'DoubleBuffer','on', ...
               'color',get(0,'defaultUicontrolBackgroundColor'), ...
               'CloseRequestFcn',@(src,event)(controller.quit()), ...
               'ResizeFcn',@(src,event)(self.resize()),...
               'Resize','on');
      %         'Color',[236 233 216]/255,...
      %         'WindowKeyPressFcn', ...
      %           @(src,event)(controller.handle_key_press(event)),...
      %         'WindowKeyReleaseFcn', ...
      %           @(src,event)(controller.handle_key_release(event)),...

      % Do some hacking to set the minimum figure size
      drawnow('update');
      drawnow('expose');
      fpj=get(handle(self.figure_h),'JavaFrame');
      jw=fpj.fHG1Client.getWindow();
      if ~isempty(jw)
        jw.setMinimumSize(java.awt.Dimension(figure_width_min, ...
                                             figure_height_min));
      end
      
      % Want to know when we get/lose focus, so have to do some hacking.
      %drawnow('update');
      %drawnow('expose');
      % % this code relies on undocumented features, and doesn't seem to
      % % work reliably on Windows XP 32-bit -- ALT, 2012-08-14
      % fpj=get(handle(self.figure_h),'JavaFrame');
      % jw=fpj.fHG1Client.getWindow;
      % jcb=handle(jw,'CallbackProperties');
      % set(jcb,'WindowGainedFocusCallback', ...
      %     @(src,event)(controller.handle_focus_gained()));
      % %set(jcb,'WindowLostFocusCallback', ...
      % %    @(src,event)(controller.handle_focus_lost()));
      % clear fpj jw jcb;

      % figure out the colorbar min and colorbar max
      colorbar_min_string='0';
      colorbar_max_string='255';
      colorbar_min=str2double(colorbar_min_string);
      colorbar_max=str2double(colorbar_max_string);

      % create the colorbar axes and the colorbar image
      self.colorbar_axes_h = ...
        axes('Parent',self.figure_h,...
             'Tag','colorbar_axes_h',...
             'Units','pixels',...
             'Visible','on',...
             'Box','on',...
             'XLim',[0.5 1.5],...
             'YLim',[colorbar_min colorbar_max],...
             'XTick',[],...
             'YAxisLocation','right', ...
             'Layer','top');
      self.colorbar_h = ...
        image('Parent',self.colorbar_axes_h,...
              'CData',(0:255)',...
              'Tag','colorbar_h',...
              'XData',[1 1],...
              'YData',[colorbar_min colorbar_max]);

      % create the image axes and the image
      self.image_axes_h = ...
        axes('Parent',self.figure_h,...
             'Tag','image_axes_h',...
             'YDir','reverse',...
             'DrawMode','normal',...
             'Visible','off',...
             'Units','pixels',...
             'DataAspectRatio',[1 1 1]);
      self.image_h = [];
      %'XLim',[0.5,image_frame_area_width+0.5],...
      %'YLim',[0.5,image_frame_area_height+0.5],...

      % VCR-style controls
      self.to_start_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','|<',...
                  'Tag','to_start_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.change_frame_abs(1)));
      self.play_backward_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','<',...
                  'Tag','play_backward_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.play(-1)));
      self.frame_backward_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','<|',...
                  'Tag','frame_backward_button_h',...
                  'enable','off',...
                  'Callback', ...
                    @(src,event)(controller.change_frame_rel(-1)));
      self.stop_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','O',...
                  'Tag','stop_button_h',...
                  'enable','off',...
                  'Callback', ...
                    @(src,event)(controller.stop_playing()));
      self.frame_forward_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','|>',...
                  'Tag','frame_forward_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.change_frame_rel(+1)));
      self.play_forward_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','>',...
                  'Tag','play_forward_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.play(+1)));
      self.to_end_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','pushbutton',...
                  'String','>|',...
                  'Tag','to_end_button_h',...
                  'enable','off',...
                  'Callback', ...
                    @(src,event)(controller.change_frame_abs(self.model.n_frames)));

      % Set the number of pixels to add to the extent to get things to look 
      % nice.  This varies by platform.
      if ismac
        edit_pad_width=14;
        edit_pad_height=7;
        % setting horizontal alignment to 'right' on mac looks ugly
        % seems like a matlab bug
        edit_horizontal_alignment='center';
        % can't set this to white on mac -- background overflows the box
        % again, seems like a matlab bug.
        % setting it to something else looks even worse.
        edit_bg_color=[1 1 1];
      else
        edit_pad_width=10;
        edit_pad_height=2;
        edit_horizontal_alignment='right';
        edit_bg_color=[1 1 1];
      end

      %
      % Frame index counter: Frame: <i> of <n> frames 
      %
      % Determine sizes of the three widgets: two text uicontrols and one
      % edit uicontrol.  For the edit, display a large string before
      % getting the extent, so we can set it's size to be as big as we'll
      % ever need it.
      self.frame_text_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','text',...
                  'String','Frame ',...
                  'Tag','frame_text_h',...
                  'BackgroundColor',get(self.figure_h,'Color'));
      frame_text_extent=get(self.frame_text_h,'Extent');
      self.frame_text_width=frame_text_extent(3);
      self.frame_text_height=frame_text_extent(4);
      self.frame_index_edit_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','edit',...
                  'String','1111111',...
                  'Tag','frame_index_edit_h',...
                  'Min',0,...
                  'Max',1,...
                  'enable','off',...
                  'HorizontalAlignment',edit_horizontal_alignment,...
                  'BackgroundColor',edit_bg_color,...
                  'Callback',@(src,event)(controller.handle_frame_index_edit()));
      frame_index_edit_extent=get(self.frame_index_edit_h,'Extent');
      self.frame_index_edit_width= ...
        frame_index_edit_extent(3)+edit_pad_width;  % need padding
      self.frame_index_edit_height= ...
        frame_index_edit_extent(4)+edit_pad_height;  % need padding
      self.of_n_frames_text_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','text',...
                  'String',' of 9999999',...
                  'HorizontalAlignment','left',...
                  'Tag','of_n_frames_text_h',...
                  'BackgroundColor',get(self.figure_h,'Color'));
      of_n_frames_text_extent=get(self.of_n_frames_text_h,'Extent');
      self.of_n_frames_text_width=of_n_frames_text_extent(3);
      self.of_n_frames_text_height=of_n_frames_text_extent(4);
      % blank strings now that we have the desired sizes
      set(self.frame_index_edit_h,'string','');
      set(self.of_n_frames_text_h,'string','');
                            
      % Determine sizes of frames per second controls
      self.FPS_text_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','text',...
                  'String','FPS: ',...
                  'Tag','FPS_text_h',...
                  'BackgroundColor',get(self.figure_h,'Color'));
      FPS_text_extent=get(self.FPS_text_h,'Extent');
      self.FPS_text_width=FPS_text_extent(3);
      self.FPS_text_height=FPS_text_extent(4);
      self.FPS_edit_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','edit',...
                  'String',sprintf('%6.2f',999),...
                  'Tag','FPS_edit_h',...
                  'Min',0,...
                  'Max',1,...
                  'enable','off',...
                  'HorizontalAlignment',edit_horizontal_alignment,...
                  'BackgroundColor',edit_bg_color,...
                  'Callback',@(src,event)(controller.handle_fps_edit()));
      FPS_edit_extent=get(self.FPS_edit_h,'Extent');
      self.FPS_edit_width=FPS_edit_extent(3)+edit_pad_width;  % padding
      self.FPS_edit_height=FPS_edit_extent(4)+edit_pad_height;  % padding
      % blank strings now that we have the desired sizes
      set(self.FPS_edit_h,'string','');

      % Mode buttons
      self.elliptic_roi_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Ellipse',...
                  'Tag','elliptic_roi_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.set_mode('elliptic_roi')),...
                  'Value',1);
      self.rect_roi_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Rect',...
                  'Tag','rect_roi_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.set_mode('rect_roi')));
      self.polygonal_roi_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Polygon',...
                  'Tag','polygonal_roi_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.set_mode('polygonal_roi')));
      self.select_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Select',...
                  'Tag','select_button_h',...
                  'Enable','off',...
                  'Callback',@(src,event)(controller.set_mode('select')));
      self.zoom_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Zoom',...
                  'Tag','zoom_button_h',...
                  'enable','off',...
                  'Callback',@(src,event)(controller.set_mode('zoom')));
      self.move_all_button_h = ...
        uicontrol('Parent',self.figure_h,...
                  'Style','togglebutton',...
                  'String','Move All',...
                  'Tag','move_all_button_h',...
                  'Enable','off',...
                  'Callback',@(src,event)(controller.set_mode('move_all')));

      %
      % add some menus
      %

      % The File menu
      self.file_menu_h= ...
        uimenu(self.figure_h,...
               'Label','File');
      self.open_video_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Open video...',...
               'Accelerator','o',...
               'Callback',@(~,~)(controller.choose_file_and_load()));
      self.open_rois_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Open ROI file...',...
               'Tag','open_rois_menu_h',...
               'enable','off',...
               'Separator','on',...
               'Callback',@(~,~)(controller.choose_roi_file_and_load()));
      self.save_rois_to_file_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Save ROIs...',...
               'Tag','save_rois_to_file_menu_h',...
               'enable','off',...
               'Callback',@(~,~)(controller.save_rois_to_file()),...
               'Enable','off');
      self.export_to_tcs_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Export ROI signals...',...
               'enable','off',...
               'Callback',@(~,~)(controller.export_to_tcs_file()),...
               'Enable','off');
      self.load_overlay_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Load overlay...',...
               'enable','off',...
               'Separator','on',...
               'Callback',@(~,~)(controller.choose_overlay_file_and_load()));
      self.quit_menu_h= ...
        uimenu(self.file_menu_h,...
               'Label','Quit',...
               'Separator','on',...
               'Callback',@(~,~)(controller.quit()));
             
      % The Edit menu
      self.edit_menu_h= ...
        uimenu(self.figure_h,...
               'Label','Edit');
      self.cut_menu_h= ...
        uimenu(self.edit_menu_h,...
               'Label','Cut',...
               'Accelerator','x',...
               'enable','off',...
               'Callback', ...
                 @(~,~)(controller.cut_selected_roi_to_clipboard()));
      self.copy_menu_h= ...
        uimenu(self.edit_menu_h,...
               'Label','Copy',...
               'Accelerator','c',...
               'enable','off',...
               'Callback', ...
                 @(~,~)(controller.copy_selected_roi_to_clipboard()));
      self.paste_menu_h= ...
        uimenu(self.edit_menu_h,...
               'Label','Paste',...
               'Accelerator','v',...
               'enable','on',...
               'Callback', ...
                 @(~,~)(controller.paste_roi_from_clipboard()));
             
      % the Color menu
      self.color_menu_h= ...
        uimenu(self.figure_h,...
               'Tag','color_menu_h',...
               'Label','Color');
      self.pixel_data_type_min_max_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','pixel_data_type_min_max_menu_h',...
               'enable','off',...
               'Label','Pixel data type min/max',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus(...
                                              'pixel_data_type_min_max')));
      self.min_max_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','min_max_menu_h',...
               'enable','off',...
               'Label','Minimum/Maximum',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus('min_max')));
      self.five_95_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','five_95_menu_h',...
               'enable','off',...
               'Label','5%/95%',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus('five_95')));
      self.abs_max_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','abs_max_menu_h',...
               'enable','off',...
               'Label','-Absolute Maximum/+Absolute Maximum',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus('abs_max')));
      self.ninety_symmetric_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','ninety_symmetric_menu_h',...
               'enable','off',...
               'Label','90% Symmetric',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus('ninety_symmetric')));
      self.colorbar_edit_bounds_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','colorbar_edit_bounds_menu_h',...
               'Label','Edit Colorbar Bounds...',...
               'Callback', ...
                 @(~,~)(controller.handle_colorbar_menus('colorbar_edit_bounds')));
      self.gray_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','gray_menu_h',...
               'Label','Gray',...
               'Callback',@(src,event)(controller.set_cmap_name('gray')),...
               'Checked','on',...
               'Separator','on');
      self.bone_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','bone_menu_h',...
               'Label','Bone',...
               'Callback',@(src,event)(controller.set_cmap_name('bone')));
      self.hot_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','hot_menu_h',...
               'Label','Hot',...
               'Callback',@(src,event)(controller.set_cmap_name('hot')));
      self.jet_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','jet_menu_h',...
               'Label','Jet',...
               'Callback',@(src,event)(controller.set_cmap_name('jet')));
      self.red_green_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','red_green_menu_h',...
               'Label','Red/Green',...
               'Callback',@(src,event)(controller.set_cmap_name('red_green')));
      self.red_blue_menu_h= ...
        uimenu(self.color_menu_h,...
               'Tag','red_blue_menu_h',...
               'Label','Red/Blue',...
               'Callback',@(src,event)(controller.set_cmap_name('red_blue')));               
      self.brighten_menu_h= ...
        uimenu(self.color_menu_h,...
               'Label','Brighten',...
               'Tag','brighten_menu_h',...
               'Accelerator','b',...
               'Callback',@(src,event)(controller.brighten()),...
               'Separator','on');
      self.darken_menu_h= ...
        uimenu(self.color_menu_h,...
               'Label','Darken',...
               'Tag','darken_menu_h',...
               'Accelerator','d',...
               'Callback',@(src,event)(controller.darken()));
      self.revert_menu_h= ...
        uimenu(self.color_menu_h,...
               'Label','Revert',...
               'Tag','revert_menu_h',...                     
               'Accelerator','r',...
               'Callback',@(src,event)(controller.revert_gamma()));

      % Mutation is complicated now that we've switched to reading in
      % a frame at a time from an on-disk file...
      %% the mutation menu
      %self.mutation_menu_h= ...
      %  uimenu(self.figure_h,...
      %         'enable','off',...
      %         'Label','Mutation');
      %self.motion_correct_menu_h= ...
      %  uimenu(self.mutation_menu_h,...
      %         'Label','Motion correct',...
      %         'Callback',@(~,~)(controller.motion_correct()),...
      %         'Enable','off');            
             
      % the ROI menu
      self.rois_menu_h= ...
        uimenu(self.figure_h,...
               'Tag','rois_menu_h',...
               'enable','off',...
               'Label','ROIs');
      self.rename_roi_menu_h= ...
        uimenu(self.rois_menu_h,...
               'Label','Rename Selected',...
               'Tag','rename_roi_menu_h',...
               'enable','off',...
               'Callback',@(~,~)(controller.rename_roi()),...
               'Enable','off');
      self.delete_roi_menu_h= ...
        uimenu(self.rois_menu_h,...
               'Label','Delete Selected',...
               'enable','off',...
               'Tag','delete_roi_menu_h',...
               'Callback',@(~,~)(controller.delete_selected_roi()),...
               'Enable','off');
      self.delete_all_rois_menu_h= ...
        uimenu(self.rois_menu_h,...
               'Label','Delete All',...
               'Tag','delete_all_rois_menu_h',...
               'enable','off',...
               'Callback',@(~,~)(controller.delete_all_rois()),...
               'Enable','off');
      self.hide_rois_menu_h= ...
        uimenu(self.rois_menu_h,...
               'Label','Hide ROIs',...
               'Tag','hide_rois_menu_h',...
               'enable','off',...
               'Callback',@(~,~)(controller.toggle_hide_rois()),...
               'Enable','off',...
               'Separator','on');

      % the Overlay menu
      self.overlay_menu_h= ...
        uimenu(self.figure_h,...
               'Tag','overlay_menu_h',...
               'Label','Overlay');
      self.show_overlay_menu_h= ...
        uimenu(self.overlay_menu_h,...
               'Label','Hide Overlay',...
               'Tag','show_overlay_menu_h',...
               'enable','off',...
               'Callback',@(~,~)(controller.toggle_show_overlay()),...
               'Enable','off');

      % Set up the view state variables
      self.frame_index=[];
      % this holds the _playback_ frame rate, in frames/sec
      self.stop_button_hit=0;
      % this is the current selection mode
      self.mode='elliptic_roi';
      self.cmap_name=cmap_name;
      self.colorbar_max_string=colorbar_max_string;
      self.colorbar_min_string=colorbar_min_string;
      self.colorbar_max=colorbar_max;
      self.colorbar_min=colorbar_min;
      % roi state
      self.selected_roi_index=zeros(0,1);
      self.hide_rois=false;
      self.border_roi_h=zeros(0,1);
      self.label_roi_h=zeros(0,1);
      % overlay state
      self.show_overlay=true;

      % have to do this last, otherwise having the pointer in the place
      % where the window appears causes an error at startup
      set(self.figure_h,'WindowButtonMotionFcn', ...
                        @(src,event)(self.update_pointer()));
    end  % constructor
    
    function [xl,yl]=get_image_viewport(self)
      xl=get(self.image_axes_h,'xlim');
      yl=get(self.image_axes_h,'ylim');
    end
    
    function indexed_frame=get.indexed_frame(self)
      % Get the current indexed_frame, based on model, frame_index,
      % colorbar_min, and colorbar_max.
      frame=double(self.model.get_frame(self.frame_index));
      cb_min=self.colorbar_min;
      cb_max=self.colorbar_max;
      indexed_frame=uint8(round(255*(frame-cb_min)/(cb_max-cb_min)));
    end
    
%     function cb_min=get.colorbar_min(self)
%       cb_min=str2double(self.cb_min_string);
%     end
% 
%     function cb_max=get.colorbar_max(self)
%       cb_max=str2double(self.cb_max_string);
%     end
% 
  end  % methods

  methods (Access=private)
  end  % methods
  
end  % classdef
