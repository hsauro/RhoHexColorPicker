unit RhoHexColorPickerFmxReg;

// Design-time registration for THexaColorPicker. This unit lives in the
// design-time package only; the runtime package contains HexaColorPicker.pas
// and carries no IDE (designide) dependency.

interface

procedure Register;

implementation

uses
  System.Classes, uRhoHexColorPickerFmx;

procedure Register;
begin
 RegisterComponents('Rhody Controls', [TRhoHexColorPicker]);
end;

end.
