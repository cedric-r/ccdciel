unit pu_goto;

{$mode objfpc}{$H+}

{
Copyright (C) 2019 Patrick Chevalley

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

uses u_utils, u_global, UScaleDPI, u_translation, u_annotation, LCLType,
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type

  { Tf_goto }

  Tf_goto = class(TForm)
    BtnSearch: TButton;
    Button1: TButton;
    Button2: TButton;
    De: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    LabelAz: TLabel;
    LabelAlt: TLabel;
    Obj: TEdit;
    Panel1: TPanel;
    Ra: TEdit;
    procedure BtnSearchClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CenterChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ObjKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    procedure SetLang;

  public

  end;

var
  f_goto: Tf_goto;

implementation

{$R *.lfm}

{ Tf_goto }

procedure Tf_goto.FormCreate(Sender: TObject);
begin
  ScaleDPI(Self);
  SetLang;
end;

procedure Tf_goto.SetLang;
begin
  Caption:=rsGoto;
  Button1.Caption:=rsGoto;
  Button2.Caption:=rsCancel;
  Label1.Caption:=rsCenterRA;
  Label2.Caption:=rsCenterDec;
  Label3.Caption:=rsObjectName;
  Label4.Caption:=rsAzimuth;
  Label5.Caption:=rsElevation;
end;

procedure Tf_goto.FormShow(Sender: TObject);
begin
  obj.SetFocus;
end;

procedure Tf_goto.ObjKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if key=VK_RETURN then BtnSearchClick(Sender);
end;

procedure Tf_goto.BtnSearchClick(Sender: TObject);
var ra0,dec0,length0,width0,pa : double;
    objname : string;
    found: boolean;
begin
  found:=false;
  objname:=uppercase(trim(Obj.Text));
  if length(objname)>1 then {Object name length should be two or longer}
  begin
    load_deep;{Load the deepsky database once. If already loaded, no action}
    linepos:=0;{Set pointer to the beginning}
    repeat
      read_deepsky('T' {full database search} ,0 {ra},0 {dec},1 {cos(telescope_dec)},2*pi{fov},{var} ra0,dec0,length0,width0,pa);{Deepsky database search}
      if ((objname=uppercase(naam2)) or (objname=uppercase(naam3)) or (objname=uppercase(naam4))) then
      begin
        Ra.Text:=RAToStr(ra0*12/pi);{Add position}
        De.Text:=DEToStr(dec0*180/pi);
        if naam3='' then
           Obj.Text:=naam2 {Add one object name only}
        else
           Obj.Text:=naam2+'_'+naam3; {Add two object names}
        linepos:=$FFFFFF; {Stop searching}
        found:=true;
     end;
    until linepos>=$FFFFFF;{Found object or end of database}
    if not found then begin
      Ra.Text:='';
      De.Text:='';
    end;
  end;
end;

procedure Tf_goto.CenterChange(Sender: TObject);
var gra,gde,az,alt:double;
    tra,tde: string;
begin
  try
  az:=0; alt:=0;
  tra:=Ra.Text;
  tde:=De.Text;
  if tra='' then
    gra:=NullCoord
  else
    gra:=StrToAR(tra);
  if tde='' then
    gde:=NullCoord
  else
    gde:=StrToDE(tde);
  if (gra<>NullCoord) and (gde<>NullCoord) then begin
    gra:=deg2rad*gra*15;
    gde:=deg2rad*gde;
    J2000ToApparent(gra,gde);
    gra:=rad2deg*gra/15;
    gde:=rad2deg*gde;
    cmdEq2Hz(gra,gde,az,alt);
    LabelAz.Caption:=FormatFloat(f2,az);
    LabelAlt.Caption:=FormatFloat(f2,alt);
  end
  else begin
    LabelAz.Caption:='-';
    LabelAlt.Caption:='-';
  end;
  except
    LabelAz.Caption:='-';
    LabelAlt.Caption:='-';
  end;
end;

end.
