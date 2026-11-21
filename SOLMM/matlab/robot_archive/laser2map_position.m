function laserMap_position= laser2map_position(scan_X,scan_Y,tftree)
%scan 雷达扫描点在笛卡尔坐标系中的坐标集
%tftree ros中的坐标变换树关系
scan_position= rosmessage('geometry_msgs/PoseStamped');
scan_position.Header.FrameId = 'laser';

scan_position.Pose.Position.X = scan_X;
scan_position.Pose.Position.Y = scan_Y;

laser_map_pose= transform(tftree, 'map', scan_position);
laserMap_position=[laser_map_pose.Pose.Position.X,laser_map_pose.Pose.Position.Y];




end

