program DemoProject;

uses
  System.StartUpCopy,
  FMX.Forms,
  DemoMain in 'DemoMain.pas' {FormDemo};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormDemo, FormDemo);
  Application.Run;
end.
