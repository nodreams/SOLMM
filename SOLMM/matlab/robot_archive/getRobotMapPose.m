function [agent,angle] = getRobotMapPose(odomData,tftree)
%odomData里程计消息 tftree 坐标变换树
%%定义一个包含小车位姿信息的消息
robot_odom_pose = rosmessage('geometry_msgs/PoseStamped');
robot_odom_pose.Header.FrameId = 'odom';
robot_odom_pose.Pose.Position.X = odomData.Pose.Pose.Position.X;
robot_odom_pose.Pose.Position.Y = odomData.Pose.Pose.Position.Y;
robot_odom_pose.Pose.Position.Z = odomData.Pose.Pose.Position.Z;
robot_odom_pose.Pose.Orientation.W = odomData.Pose.Pose.Orientation.W;
robot_odom_pose.Pose.Orientation.X = odomData.Pose.Pose.Orientation.X;
robot_odom_pose.Pose.Orientation.Y = odomData.Pose.Pose.Orientation.Y;
robot_odom_pose.Pose.Orientation.Z = odomData.Pose.Pose.Orientation.Z;
%使用tf树将odom坐标系中的小车位姿转换到map坐标系中
robot_map_pose = transform(tftree, 'map', robot_odom_pose);
%取二元平面数据作为小车的的坐标
robot_map_pose_point=[robot_map_pose.Pose.Position.X,robot_map_pose.Pose.Position.Y];
%计算小车方向
quat = robot_map_pose.Pose.Orientation;
angles = quat2eul([quat.W quat.X quat.Y quat.Z]);%四元数转换成欧拉角 默认zyx旋转方式相对map的欧拉角
theta_map = rad2deg(angles(1));%将欧拉角的弧度制改为角度
if theta_map<0
    theta_map=theta_map+360;%%%从-180-180转换为0到360
end
agent = robot_map_pose_point;
angle=theta_map;
end

