#BY FGPRC, WIP

points = getprop("/autopilot/route-manager/route/num");

crtPageNum = getprop("/autopilot/route-manager/route/crtPageNum");

var turnLEGS = func(move)
{
	if(move == 1 and crtPageNum <= pageNum){crtPageNum = crtPageNum + 1;}
	else if(move == 0 and crtPageNum != 1){crtPageNum = crtPageNum - 1;}
	
	setprop("/autopilot/route-manager/route/crtPageNum",crtPageNum);
}
#Display phase

var getLEGS = {	
		angle2Point : func(line) 
			{
				if(getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/leg-bearing-true-deg") != nil)
				{
					return sprintf("%3.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/leg-bearing-true-deg"));
					}
				else
				{return "";}
			},
		id : func(line)
			{
				if(getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/id") != nil)
				{
					return getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/id");
					}
				else
				{return "";}
			},
		distance : func(line)
			{
				if(getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/leg-distance-nm") != nil)
				{
					return sprintf("%3.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/leg-distance-nm"))~" NM";
					}
				else
				{return "";}
			},
		altSpdLimit : func(line)
			{
				if(getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/speed-kts") != nil)
				{
					var tmp = "";
					tmp = sprintf("%5.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+1)~"]/speed-kts"))~"/"~sprintf("%5.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+1)~"]/altitude-ft"));
					return tmp;
				}
				else if(getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/altitude-ft") != nil)
				{
					return sprintf("%5.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) *5)+line)~"]/altitude-ft"));
				}
				else	
				{return "";}
			},
	};
	#var pageNum = math.ceil(points / 5);
	#if(pageNum == nil)
	#	{
	#		page = "";
	#	}
	#	else
	#	{page = crtPageNum ~ "/" ~ pageNum;}
	
	#if (actName != nil)
	#{
	#	line1lt = sprintf("%3.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/leg-bearing-true-deg"));
	#	line1l = getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/id");
	#	line2ct = sprintf("%3.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/leg-distance-nm"))~" NM";
	#	line1r = sprintf("%5.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/altitude-ft"));
	#	if (getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/speed-kts") != nil)
	#	{
	#		line1r = getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/speed-kts")~"/"~sprintf("%5.0f", getprop("/autopilot/route-manager/route/wp["~(((crtPageNum -1) /5)+1)~"]/altitude-ft"));
	#	}
	#}