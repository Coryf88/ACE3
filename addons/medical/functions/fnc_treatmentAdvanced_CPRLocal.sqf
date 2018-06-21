/*
 * Author: Glowbal, edited by BROMA
 * local Callback for the CPR treatment action on success.
 *
 * Arguments:
 * 0: The medic <OBJECT>
 * 1: The patient <OBJECT>
 *
 * Return Value:
 * Succesful treatment started <BOOL>
 *
 * Example:
 * [medic, patient] call ace_medical_fnc_treatmentAdvanced_CPRLocal
 *
 * Public: Yes
 */

#include "script_component.hpp"

#define CARDIAC_HEART_RATE 40
#define REVIVE_HEART_RATE (40 + (floor (random [10, 15, 20])))

#define NORMAL_TIME_DEVIATION 100
#define MEDIC_TIME_DEVIATION 25
#define DOCTOR_TIME_DEVIATION 5

params ["_caller", "_target"];

private _fnc_addToLog = {
    params ["_unit", "_message", "_arguments"];
    [_unit, "activity", _message, _arguments] call FUNC(addToLog);
    [_unit, "activity_view", _message, _arguments] call FUNC(addToLog);
};

private _fnc_cprSuccess = {
    params ["_target", "_state", "_heartRate"];

    _target setVariable [_state, nil, true];
    _target setVariable [QGVAR(heartRate), _heartRate];

    private _bloodPressure = [_target] call FUNC(getBloodPressure);
    _bloodPressure params [ "_bloodPressureLow", "_bloodPressureHigh"];
    _bloodPressureLow = (_bloodPressureLow max 50) + floor (random [5, 10, 30]);
    _bloodPressureHigh = (_bloodPressureHigh max 70) + floor (random [5, 10, 30]);
    _target setVariable [QGVAR(bloodPressure), [_bloodPressureLow, _bloodPressureHigh]];

    [_target, false] call FUNC(setUnconscious);

};

if (_target getVariable [QGVAR(inReviveState), false]) exitWith {
    private _medicClass = _caller getVariable [QGVAR(medicClass), [0, 1] select (_caller getUnitTrait "medic")];
    private _stableCondition = [_target] call FUNC(isInStableCondition);

    private _fnc_updateReviveTime = {
        params ["_target", "_stableCondition", "_medicClass", "_nameTarget"];

        private _reviveStartTime = _target getVariable [QGVAR(reviveStartTime), 0];
        if (_reviveStartTime > 0) then {
            _reviveStartTime = (if (_stableCondition) then {
                _reviveStartTime + (floor (random [20, 40, 60]))
            } else {
                private _bleedingRate = ([_target] call FUNC(getBloodLoss)) * 100;
                _reviveStartTime - (floor (random [_bleedingRate / 1.5, _bleedingRate, _bleedingRate * 1.5]) max 0)
            }) min CBA_missionTime;

            _target setVariable [QGVAR(reviveStartTime), _reviveStartTime];

            private _remainingReviveTime = GVAR(maxReviveTime) - (CBA_missionTime - _reviveStartTime);
            private _timeOffset = [NORMAL_TIME_DEVIATION, MEDIC_TIME_DEVIATION, DOCTOR_TIME_DEVIATION] select _medicClass;
            private _timeleft = ((floor _remainingReviveTime) + (floor (random [_timeOffset * -1, 0, _timeOffset]))) max 1;

            private _reviveTimeMsg = if (_medicClass > 0) then {
                if (_timeleft <= 15) exitWith {
                    LSTRING(Activity_CPR_revive_time_low_medic);
                };
                LSTRING(Activity_CPR_revive_time_medic);
            } else {
                if (_timeleft < 60) exitWith {
                    LSTRING(Activity_CPR_revive_time_low);
                };
                _timeleft = floor (_timeleft / 60);
                LSTRING(Activity_CPR_revive_time);
            };

            [_target, _reviveTimeMsg, [_timeleft, _nameTarget]] call _fnc_addToLog;
        };
    };

    if (_stableCondition) then {
        if (_target getVariable [QGVAR(bloodVolume), 100] >= 30 && {(random 1) > 0.8}) then {
            [_target, QGVAR(inReviveState), REVIVE_HEART_RATE] call _fnc_cprSuccess;
        } else {
            if (GVAR(maxReviveTime) > 0) then {
                [_target, _stableCondition, _medicClass, [_target] call EFUNC(common,getName)] call _fnc_updateReviveTime;
            };

            if (_medicClass > 0) then {
                [_target, LSTRING(Activity_CPR_stabilized), []] call _fnc_addToLog;
            };
        };
    } else {
        if (GVAR(maxReviveTime) > 0) then {
            private _nameTarget = [_target] call EFUNC(common,getName);
            [_target, if (_medicClass > 0) then { LSTRING(Activity_CPR_bleeding_medic) } else { LSTRING(Activity_CPR_bleeding) }, [[_caller] call EFUNC(common,getName), _nameTarget]] call _fnc_addToLog;

            [_target, _stableCondition, _medicClass, _nameTarget] call _fnc_updateReviveTime;
        };
    };

    true;
};

if (GVAR(level) > 1 && {(random 1) >= 0.5}) then {
    [_target, QGVAR(inCardiacArrest), CARDIAC_HEART_RATE] call _fnc_cprSuccess;
};

[_target, LSTRING(Activity_CPR), [[_caller, false, true] call EFUNC(common,getName)]] call _fnc_addToLog; // TODO expand message

true;
