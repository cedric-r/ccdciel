unit cu_indisafety;

{$mode objfpc}{$H+}

{
Copyright (C) 2018 Patrick Chevalley

http://www.ap-i.net
pch@ap-i.net

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. 

}

interface

uses cu_safety, indibaseclient, indibasedevice, indiapi, indicom, u_translation,
     u_global, ExtCtrls, Forms, Classes, SysUtils;

type

T_indisafety = class(T_safety)
 private
   indiclient: TIndiBaseClient;
   InitTimer: TTimer;
   ConnectTimer: TTimer;
   SafetyDevice: Basedevice;
   SafetyStatus: ILightVectorProperty;
   configprop: ISwitchVectorProperty;
   configload,configsave: ISwitch;
   Fready,Fconnected: boolean;
   Findiserver, Findiserverport, Findidevice: string;
   stSafe: boolean;
   procedure CreateIndiClient;
   procedure InitTimerTimer(Sender: TObject);
   procedure ConnectTimerTimer(Sender: TObject);
   procedure ClearStatus;
   procedure CheckStatus;
   procedure NewDevice(dp: Basedevice);
   procedure NewMessage(mp: IMessage);
   procedure NewProperty(indiProp: IndiProperty);
   procedure NewNumber(nvp: INumberVectorProperty);
   procedure NewText(tvp: ITextVectorProperty);
   procedure NewSwitch(svp: ISwitchVectorProperty);
   procedure NewLight(lvp: ILightVectorProperty);
   procedure DeleteDevice(dp: Basedevice);
   procedure DeleteProperty(indiProp: IndiProperty);
   procedure ServerConnected(Sender: TObject);
   procedure ServerDisconnected(Sender: TObject);
   procedure LoadConfig;
 protected
   function  GetSafe:boolean; override;
   procedure SetTimeout(num:integer); override;
 public
   constructor Create(AOwner: TComponent);override;
   destructor  Destroy; override;
   Procedure Connect(cp1: string; cp2:string=''; cp3:string=''; cp4:string='');  override;
   Procedure Disconnect; override;

end;

implementation

procedure T_indisafety.CreateIndiClient;
begin
if csDestroying in ComponentState then exit;
  indiclient:=TIndiBaseClient.Create;
  indiclient.onNewDevice:=@NewDevice;
  indiclient.onNewMessage:=@NewMessage;
  indiclient.onNewProperty:=@NewProperty;
  indiclient.onNewNumber:=@NewNumber;
  indiclient.onNewText:=@NewText;
  indiclient.onNewSwitch:=@NewSwitch;
  indiclient.onNewLight:=@NewLight;
  indiclient.onDeleteDevice:=@DeleteDevice;
  indiclient.onDeleteProperty:=@DeleteProperty;
  indiclient.onServerConnected:=@ServerConnected;
  indiclient.onServerDisconnected:=@ServerDisconnected;
  ClearStatus;
end;

constructor T_indisafety.Create(AOwner: TComponent);
begin
 inherited Create(AOwner);
 FSafetyInterface:=INDI;
 ClearStatus;
 Findiserver:='localhost';
 Findiserverport:='7624';
 Findidevice:='';
 InitTimer:=TTimer.Create(nil);
 InitTimer.Enabled:=false;
 InitTimer.Interval:=60000;
 InitTimer.OnTimer:=@InitTimerTimer;
 ConnectTimer:=TTimer.Create(nil);
 ConnectTimer.Enabled:=false;
 ConnectTimer.Interval:=3000;
 ConnectTimer.OnTimer:=@ConnectTimerTimer;
 CreateIndiClient;
end;

destructor  T_indisafety.Destroy;
begin
 InitTimer.Enabled:=false;
 ConnectTimer.Enabled:=false;
 indiclient.onServerDisconnected:=nil;
 indiclient.Free;
 FreeAndNil(InitTimer);
 FreeAndNil(ConnectTimer);
 inherited Destroy;
end;

procedure T_indisafety.ClearStatus;
begin
    SafetyDevice:=nil;
    SafetyStatus:=nil;
    configprop:=nil;
    Fready:=false;
    Fconnected := false;
    stSafe:=false;
    FStatus := devDisconnected;
    if Assigned(FonStatusChange) then FonStatusChange(self);
end;

procedure T_indisafety.CheckStatus;
begin
    if Fconnected and
       (configprop<>nil) and
       (SafetyStatus<>nil)
    then begin
       FStatus := devConnected;
       if (not Fready) then begin
         Fready:=true;
         if FAutoloadConfig then begin
           LoadConfig;
         end;
         if Assigned(FonStatusChange) then FonStatusChange(self);
       end;
    end;
end;

Procedure T_indisafety.Connect(cp1: string; cp2:string=''; cp3:string=''; cp4:string='');
begin
if (indiclient=nil)or(indiclient.Terminated) then CreateIndiClient;
if not indiclient.Connected then begin
  Findiserver:=cp1;
  Findiserverport:=cp2;
  Findidevice:=cp3;
  Fdevice:=cp3;
  FStatus := devDisconnected;
  if Assigned(FonStatusChange) then FonStatusChange(self);
  indiclient.SetServer(Findiserver,Findiserverport);
  indiclient.watchDevice(Findidevice);
  indiclient.ConnectServer;
  FStatus := devConnecting;
  if Assigned(FonStatusChange) then FonStatusChange(self);
  InitTimer.Enabled:=true;
end
else msg(' Safety already connected',0);
end;

procedure T_indisafety.InitTimerTimer(Sender: TObject);
begin
  InitTimer.Enabled:=false;
  if (SafetyDevice=nil)or(not Fready) then begin
    msg(rsError2,0);
    if not Fconnected then begin
      msg(rsNoResponseFr,0);
      msg('Is "'+Findidevice+'" a running safety driver?',0);
    end
    else if (configprop=nil) then
       msg('Safety '+Findidevice+' Missing property CONFIG_PROCESS',0)
    else if (SafetyStatus=nil) then
       msg('Safety '+Findidevice+' Missing property WEATHER_STATUS',0);
    Disconnect;
  end;
end;

Procedure T_indisafety.Disconnect;
begin
InitTimer.Enabled:=False;
ConnectTimer.Enabled:=False;
indiclient.Terminate;
ClearStatus;
end;

procedure T_indisafety.ServerConnected(Sender: TObject);
begin
   ConnectTimer.Enabled:=True;
end;

procedure T_indisafety.ConnectTimerTimer(Sender: TObject);
begin
  ConnectTimer.Enabled:=False;
  if (not Fready) and InitTimer.Enabled then begin
    ConnectTimer.Enabled:=true;
  end;
  indiclient.connectDevice(Findidevice);
end;

procedure T_indisafety.ServerDisconnected(Sender: TObject);
begin
  FStatus := devDisconnected;
  if Assigned(FonStatusChange) then FonStatusChange(self);
  msg(rsServer+' '+rsDisconnected3,0);
  CreateIndiClient;
end;

procedure T_indisafety.NewDevice(dp: Basedevice);
begin
  //writeln('Newdev: '+dp.getDeviceName);
  if dp.getDeviceName=Findidevice then begin
     Fconnected:=true;
     SafetyDevice:=dp;
  end;
end;

procedure T_indisafety.DeleteDevice(dp: Basedevice);
begin
  if dp.getDeviceName=Findidevice then begin
     Disconnect;
  end;
end;

procedure T_indisafety.DeleteProperty(indiProp: IndiProperty);
begin
  { TODO :  check if a vital property is removed ? }
end;

procedure T_indisafety.NewMessage(mp: IMessage);
begin
  if Assigned(FonDeviceMsg) then FonDeviceMsg(Findidevice+': '+mp.msg);
  mp.free;
end;

procedure T_indisafety.NewProperty(indiProp: IndiProperty);
var propname: string;
    proptype: INDI_TYPE;
    TxtProp: ITextVectorProperty;
    Txt: IText;
    buf: string;
begin
  propname:=indiProp.getName;
  proptype:=indiProp.getType;

  if (proptype=INDI_TEXT)and(propname='DRIVER_INFO') then begin
     buf:='';
     TxtProp:=indiProp.getText;
     if TxtProp<>nil then begin
       Txt:=IUFindText(TxtProp,'DRIVER_EXEC');
       if Txt<>nil then buf:=buf+Txt.lbl+': '+Txt.Text+', ';
       Txt:=IUFindText(TxtProp,'DRIVER_VERSION');
       if Txt<>nil then buf:=buf+Txt.lbl+': '+Txt.Text+', ';
       Txt:=IUFindText(TxtProp,'DRIVER_INTERFACE');
       if Txt<>nil then buf:=buf+Txt.lbl+': '+Txt.Text;
       msg(buf,9);
     end;
  end
  else if (proptype=INDI_SWITCH)and(configprop=nil)and(propname='CONFIG_PROCESS') then begin
     configprop:=indiProp.getSwitch;
     configload:=IUFindSwitch(configprop,'CONFIG_LOAD');
     configsave:=IUFindSwitch(configprop,'CONFIG_SAVE');
     if (configload=nil)or(configsave=nil) then configprop:=nil;
  end
  else if (proptype=INDI_LIGHT)and(SafetyStatus=nil)and(propname='WEATHER_STATUS') then begin
     SafetyStatus:=indiProp.getLight;
  end;
  CheckStatus;
end;

procedure T_indisafety.NewNumber(nvp: INumberVectorProperty);
begin
end;

procedure T_indisafety.NewText(tvp: ITextVectorProperty);
begin
//  writeln('NewText: '+tvp.name+' '+tvp.tp[0].text);
end;

procedure T_indisafety.NewSwitch(svp: ISwitchVectorProperty);
begin
//  writeln('NewSwitch: '+svp.name);
end;

procedure T_indisafety.NewLight(lvp: ILightVectorProperty);
var ok: boolean;
begin
  if lvp=SafetyStatus then begin
    ok:=SafetyStatus.s=IPS_OK;
    if ok<>stSafe then begin
      stSafe:=ok;
      if Assigned(FonSafeChange) then FonSafeChange(self);
    end;
  end;
end;

function  T_indisafety.GetSafe:Boolean;
begin
  result:=false;
  { TODO : process other properties }
  if SafetyStatus<>nil then begin
     result:=SafetyStatus.s=IPS_OK;
  end;
end;

procedure T_indisafety.SetTimeout(num:integer);
begin
 FTimeOut:=num;
 indiclient.Timeout:=FTimeOut;
end;

procedure T_indisafety.LoadConfig;
begin
  if configprop<>nil then begin
    IUResetSwitch(configprop);
    configload.s:=ISS_ON;
    indiclient.sendNewSwitch(configprop);
  end;
end;

end.

