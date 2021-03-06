print("Loading RNDInfoPopup.lua from Real Natural Disasters version "..GlobalParameters.RND_VERSION_MAJOR.."."..GlobalParameters.RND_VERSION_MINOR.."."..GlobalParameters.RND_VERSION_PATCH);
-- ===========================================================================
-- Real Natural Disasters
-- Author: Infixo
-- Created: March 31st - April 1st, 2017
-- ===========================================================================

if ExposedMembers.RND == nil then ExposedMembers.RND = {} end;
local RND = ExposedMembers.RND;


-- ===========================================================================
-- DEBUG ROUTINES
-- ===========================================================================

-- debug output routine
function dprint(sStr,p1,p2,p3,p4,p5,p6)
	if true then return; end
	local sOutStr = sStr;
	if p1 ~= nil then sOutStr = sOutStr.." [1] "..tostring(p1); end
	if p2 ~= nil then sOutStr = sOutStr.." [2] "..tostring(p2); end
	if p3 ~= nil then sOutStr = sOutStr.." [3] "..tostring(p3); end
	if p4 ~= nil then sOutStr = sOutStr.." [4] "..tostring(p4); end
	if p5 ~= nil then sOutStr = sOutStr.." [5] "..tostring(p5); end
	if p6 ~= nil then sOutStr = sOutStr.." [6] "..tostring(p6); end
	print(sOutStr);
end



-- ===========================================================================
-- CONTENT FUNCTIONS
-- ===========================================================================

function ShowTheParameters()
	dprint("FUNCAL ShowTheParameters()");
	
	Controls.HeaderLabel:SetText(Locale.Lookup("LOC_RNDINFO_LINE_MOD_NAME"));
	Controls.DisasterReportLabel:SetHide(true);
	
	local tOutputStrings:table = {};
	local sLine:string = "";
	
	-- map data
	MapConfiguration.GetScript()
	local iMapWidth:number, iMapHeight:number = Map.GetGridSize();
	local iMapSize:number = iMapWidth * iMapHeight;
	sLine = Locale.Lookup("LOC_RNDINFO_LINE_MAP_INFO", MapConfiguration.GetScript(), iMapWidth, iMapHeight, iMapSize);
	table.insert(tOutputStrings, sLine);
	
	-- parameters
	table.insert(tOutputStrings, Locale.Lookup("LOC_RNDINFO_LINE_PARAMS"));
	-- retrieve and show custom parameters
	local function RetrieveParameter(sParName:string, iDefault:number)
		local par = GameConfiguration.GetValue(sParName);
		if par == nil then par = iDefault; else par = tonumber(par); end
		--dprint("Retrieving (par,def,out)", sParName, iDefault, par);
		sLine = "[ICON_Bullet]"..sParName.." = "..par;
		table.insert(tOutputStrings, sLine);
	end
	RetrieveParameter("RNDConfigNumDis", 100);
	RetrieveParameter("RNDConfigAdjMapSize", 1);
	RetrieveParameter("RNDConfigMagnitude", 0);
	RetrieveParameter("RNDConfigRange", 0);

	-- number of events
	table.insert(tOutputStrings, Locale.Lookup("LOC_RNDINFO_LINE_EXPECT"));
	local iGameSpeedMultiplier = GameInfo.GameSpeeds[GameConfiguration.GetGameSpeedType()].CostMultiplier;
	local iTotEvents:number = 0; -- x1000
	for _, disaster in pairs(RND.tDisasterTypes) do
		local numEvents = math.floor(disaster.BaseProbability * disaster.NumStartPlots * 500 * (iGameSpeedMultiplier/100) / 1000);
		sLine = Locale.Lookup("LOC_RNDINFO_LINE_DISASTER", disaster.Name, math.floor(0.5+numEvents/1000), disaster.NumStartPlots, disaster.BaseProbability);
		table.insert(tOutputStrings, sLine);
		iTotEvents = iTotEvents + numEvents;
	end
	sLine = Locale.Lookup("LOC_RNDINFO_LINE_SUMMARY", math.floor(0.5+iTotEvents/1000));
	table.insert(tOutputStrings, sLine);
	
	-- show the loooong string
	Controls.DisasterDamageDesc:SetText(table.concat(tOutputStrings, "[NEWLINE]"));
	Controls.DisasterDamageScroll:CalculateSize();

end


local iShownTurn:number = 0;
local iShownStartingPlot:number = 0;
local iShownEffects:number = 0;

function ShowTheDisaster()
	dprint("FUNCAL ShowTheDisaster()");
	local tTheDisaster = RND.tTheDisaster;
	local tDisaster = tTheDisaster.DisasterType;
	
	-- check if maybe we're already showing the right one
	--if tTheDisaster.Turn == iShownTurn and tTheDisaster.StartingPlot == iShownStartingPlot and #tTheDisaster.Effects == iShownEffects then return; end

	-- check for our own units and plots
	local sLocalOwner:string;
	local eLocalPlayer = Game.GetLocalPlayer();
	if eLocalPlayer ~= -1 then sLocalOwner = Locale.Lookup(PlayerConfigurations[eLocalPlayer]:GetCivilizationShortDescription());
	else sLocalOwner = nil; end
	
	-- Update header text and Icon
	local sHeaderLabel = Locale.ToUpper(Locale.Lookup(tDisaster.Name));
	--dprint("  sHeaderLabel", sHeaderLabel);
	Controls.HeaderLabel:SetText(sHeaderLabel);
	Controls.DisasterReportLabel:SetHide(false);
	--dprint("  icon", tDisaster.Icon, IconManager:FindIconAtlas( GameInfo.RNDDisasters[tDisaster.Type].Icon, 80 ))
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas( GameInfo.RNDDisasters[tDisaster.Type].Icon, 80 );
	if (textureOffsetX ~= nil) then
		Controls.DisasterIcon:SetTexture( textureOffsetX, textureOffsetY, textureSheet );
	end
	
	-- Update general Info
	local sMsg:string = "";
	local pPlot = Map.GetPlotByIndex(tTheDisaster.StartingPlot);
	local iSize = table.count(tTheDisaster.Plots);
	--sMsg = sMsg.."In year [ICON_Turn]"..tTheDisaster.Year.." the [COLOR_Red]"..tDisaster.Name.."[ENDCOLOR] of magnitude [COLOR_Red]"..tTheDisaster.StartingMagnitude;
	--sMsg = sMsg.."[ENDCOLOR] that started at coordinates ("..pPlot:GetX()..","..pPlot:GetY()..") devastated [COLOR_Red]"..iSize.."[ENDCOLOR] tiles.";
	--dprint("  sMsg", sMsg);
	sMsg = Locale.Lookup("LOC_RNDINFO_GENERAL_INFO", tTheDisaster.Year, tDisaster.Name, tTheDisaster.StartingMagnitude, pPlot:GetX(), pPlot:GetY(), table.count(tTheDisaster.Plots));
	Controls.DisasterGeneralInfo:SetText(sMsg);

	-- Update damage info
	-- As for now it displays only formatted strings
	-- (*) TILE XX (m) belongs to City, Civ
	--  - effect info 1
	--  - effect info 2
	-- (*) TILE XX (m) unpopulated
	--  - effect info 1
	-- Tiles with NO damage WON'T be shown
	-- this will be tricky as we have to generate a huuuge string
	-- table.concat(table,"[NEWLINE"]) will be used
	
	local tOutputStrings:table = {};
	local sLine:string = "";
	
	-- debug
	dprint("There are (n) effects to show", table.count(tTheDisaster.Effects));
	--for _, effect in ipairs(tTheDisaster.Effects) do effect:dshoweffect(); end
	
	for i, iPlot in ipairs(tTheDisaster.Plots) do
	
		-- filter effects
		local tEffects:table = {};  -- will store effects for a given plot
		for _, effect in ipairs(tTheDisaster.Effects) do
			if effect.Plot == iPlot then table.insert(tEffects, effect); end --dprint("  ...found an effect for plot", effect.Plot); end
		end
		--dprint("For plot (idx) found (n) effects", iPlot, table.count(tEffects));
		
		if table.count(tEffects) > 0 then
			-- first show Plot info
			local pPlot = Map.GetPlotByIndex(iPlot);
			if pPlot == nil then print("ERROR ShowTheDisaster() no plot with id", iPlot); break; end
			if pPlot:IsWater() then sLine = Locale.Lookup("LOC_RNDINFO_PLOT_WATER_AT", pPlot:GetX(), pPlot:GetY());  --sLine = "Water at (";
			else                    sLine = Locale.Lookup("LOC_RNDINFO_PLOT_LAND_AT",  pPlot:GetX(), pPlot:GetY()); end  --sLine = "Land at ("; end
			--sLine = sLine..pPlot:GetX()..","..pPlot:GetY()..")";
			-- check if there's an owner
			local sOwnerCiv:string, sOwnerCity:string = "", "";
			if pPlot:IsOwned() then
				sLine = sLine.." "..Locale.Lookup("LOC_RNDINFO_PLOT_OWNED_BY").." ";
				local eOwner = pPlot:GetOwner();
				local pCity = Cities.GetPlotPurchaseCity(pPlot);
				--dprint("  plot owned by (civ,city)", eOwner, pCity:GetID());
				sOwnerCiv = PlayerConfigurations[eOwner]:GetCivilizationShortDescription();  -- LOC_CIVILIZATION_AMERICA_NAME
				sOwnerCiv = Locale.Lookup(sOwnerCiv);
				sOwnerCity = Locale.Lookup(pCity:GetName());
				--dprint("  plot owned by (civ,city)", sOwnerCiv, sOwnerCity);
				if eOwner == eLocalPlayer then
					sLine = sLine.."[COLOR_Blue]"..sOwnerCiv.."[ENDCOLOR] ";
					sLine = sLine.."([COLOR_Blue]"..sOwnerCity.."[ENDCOLOR])";  -- the name of our cities is always different than Civ name (not a Minor)
				elseif Players[eLocalPlayer]:GetDiplomacy():HasMet(eOwner) then
					sLine = sLine..sOwnerCiv;
					if sOwnerCiv ~= sOwnerCity then sLine = sLine.." ("..sOwnerCity..")"; end
				else
					sLine = sLine..Locale.Lookup("LOC_RNDINFO_UNKNOWN_CIV");
				end
			else
				sLine = sLine.." "..Locale.Lookup("LOC_RNDINFO_PLOT_WITHOUT_OWNER"); -- " without owner";
			end
			-- add magnitude info
			sLine = sLine.." "..Locale.Lookup("LOC_RNDINFO_PLOT_WAS_HIT", tTheDisaster.Magnitudes[i]);  --" was hit with "..tTheDisaster.Magnitudes[i].." strength.";
			table.insert(tOutputStrings, sLine);
			-- show effects
			for _, effect in ipairs(tEffects) do
				sLine = "[ICON_Bullet]"..effect.Desc;
				table.insert(tOutputStrings, sLine);
			end
		end -- tEffects > 0
	end -- main Plots loop
	
	-- show the loooong string or short notice only
	if table.count(tOutputStrings) == 0 then 
		Controls.DisasterDamageDesc:SetText(Locale.Lookup("LOC_RNDINFO_SUMMARY_NO_DAMAGE", sHeaderLabel));
	else
		Controls.DisasterDamageDesc:SetText(table.concat(tOutputStrings, "[NEWLINE]"));
		Controls.DisasterDamageScroll:CalculateSize();
	end
	
	-- sounds are not so loud any more, but also they will be played only if disaster is actually visible
    if tTheDisaster:IsDisasterVisible() then
		UI.PlaySound(tDisaster.Sound);
		ContextPtr:SetHide(false); -- Version 2.3.0
	end
	
	iShownTurn = tTheDisaster.Turn;
	iShownStartingPlot = tTheDisaster.StartingPlot;
	iShownEffects = #tTheDisaster.Effects;
end


-- ===========================================================================
-- WINDOW CONTROLS FUNCTIONS
-- ===========================================================================

function OpenWindow()
	dprint("FUNCAL OpenWindow() player", Game.GetLocalPlayer());
	if Players[Game.GetLocalPlayer()] == nil then return; end
	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
		ShowTheParameters();
		ContextPtr:SetHide(false); -- params are always visible
	else
		ShowTheDisaster();
	end  -- main function
	--ContextPtr:SetHide(false); -- Version 2.3.0
	--UI.PlaySound("UI_Screen_Open");
end

-- ===========================================================================
function CloseWindow()
	dprint("FUNCAL CloseWindow() player", Game.GetLocalPlayer());
	-- might add some clean-up here, but not necessary right now
	ContextPtr:SetHide(true);
	--ContextPtr:ClearUpdate();  -- ???
	UI.PlaySound("UI_Screen_Close");
end

-- ===========================================================================
function OnClose()	
	dprint("FUNCAL OnClose()");
	-- Dequeue popup from UI mananger
	--[[UIManager:DequeuePopup( ContextPtr );
	m_isPopupQueued = false;
	--]]
	ContextPtr:SetHide(true);
	UI.PlaySound("UI_Screen_Close");
end

-- ===========================================================================
function OnInit( isHotload:boolean )
	-- not used now, might be in the future
end

-- ===========================================================================
function OnInputHandler( input )
	local msg = input:GetMessageType();
	if (msg == KeyEvents.KeyUp) then
		local key = input:GetKey();
		if key == Keys.VK_ESCAPE then
			OnClose();
			return true;
		end
	end
	return false;
end

function OnLocalPlayerTurnBegin()
	dprint("FUNCAL OnLocalPlayerTurnBegin()");
end

-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		OnClose();
	end
end


-- ===========================================================================
-- INITIALIZATION
-- ===========================================================================

function Initialize()

	-- initialize window
	ContextPtr:SetHide(true);
	--ContextPtr:SetInitHandler( OnInit );  -- for future
	ContextPtr:SetInputHandler( OnInputHandler, true );  -- escape key
	
	-- control events
	Controls.ContinueButton:RegisterCallback( Mouse.eLClick, OnClose );

	-- game events
	--Events.LocalPlayerTurnBegin.Add( OnLocalPlayerTurnBegin );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );  -- close window if HotSeat
	
	-- inter-module events - only works in UI context!
	LuaEvents.RNDInfoPopup_OpenWindow.Add(OpenWindow);
	-- Gathering Storm doesn't allow for Gameplay -> UI events, so let's try ExposedMembers
	ExposedMembers.RND.RNDInfoPopup_OpenWindow = OpenWindow;

end
Initialize();	

print("OK loaded RNDInfoPopup.lua from Real Natural Disasters");