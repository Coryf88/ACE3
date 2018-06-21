/*
 * Author: BROMA
 * local Callback for the Defibrillator treatment action on success.
 *
 * Arguments:
 * 0: The medic <OBJECT>
 * 1: The patient <OBJECT>
 *
 * Return Value:
 * Succesful treatment started <BOOL>
 *
 * Public: Yes
 */

#include "script_component.hpp"

params ["_caller", "_target"];

if (alive _target && {(_target getVariable [QGVAR(inCardiacArrest), false] || _target getVariable [QGVAR(inReviveState), false])}) then {
    playSound3D [QUOTE(PATHTO_R(sounds\def\successful.ogg)), _caller, false, getPosASL _caller, 2, 1, 50];

    [_target, _caller] spawn {
        params ["_target", "_caller"];

        sleep 0.6;

        if (_target getVariable [QGVAR(bloodVolume), 100] >= 30 && {random(1) >= 0.1}) then {
            playSound3D [QUOTE(PATHTO_R(sounds\def\good_beep.ogg)), _caller, false, getPosASL _caller, 2, 1, 50];

            private _bloodPressure = [_target] call FUNC(getBloodPressure);
            _bloodPressure params [["_bloodPressureLow", 60], ["_bloodPressureHigh", 80]];
            _bloodPressureLow = (_bloodPressureLow max 60) + floor (random [5, 10, 30]);
            _bloodPressureHigh = (_bloodPressureHigh max 80) + floor (random [5, 10, 30]);

            _target setVariable [QGVAR(inReviveState), nil, true];
            _target setVariable [QGVAR(inCardiacArrest), nil, true];
            _target setVariable [QGVAR(heartRate), 80, true];
            _target setVariable [QGVAR(bloodPressure), [_bloodPressureLow, _bloodPressureHigh]];
            [_target, false] call FUNC(setUnconscious);

            [_target, "activity", LSTRING(Activity_DEF_Good), [[_caller, false, true] call EFUNC(common,getName)]] call FUNC(addToLog);
            [_target, "activity_view", LSTRING(Activity_DEF_Good), [[_caller, false, true] call EFUNC(common,getName)]] call FUNC(addToLog);
        } else {
            playSound3D [QUOTE(PATHTO_R(sounds\def\bad_beep.ogg)), _caller, false, getPosASL _caller, 2, 1, 50];

            [_target, "activity", LSTRING(Activity_DEF_Bad), [[_caller, false, true] call EFUNC(common,getName)]] call FUNC(addToLog);
            [_target, "activity_view", LSTRING(Activity_DEF_Bad), [[_caller, false, true] call EFUNC(common,getName)]] call FUNC(addToLog);
        };
    };
};

true;
