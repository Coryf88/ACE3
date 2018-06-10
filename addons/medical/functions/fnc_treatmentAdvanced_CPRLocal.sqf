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

#define BLOOD_LOSS_MEDIC_MSG "%1's CPR further worsened the patient's hemorrhaging."
#define REVIVE_TIME_MEDIC_MSG "%2 has an estimated %1 seconds until exsanguination."
#define REVIVE_TIME_LOW_MEDIC_MSG "The patient is not going to make it."

#define BLOOD_LOSS_NORMAL_MSG "Seems like %1's CPR pumped blood out of their wounds."
#define REVIVE_TIME_NORMAL_MSG "Looks like they'll die in about %1 minutes."
#define REVIVE_TIME_LOW_NORMAL_MSG "They'll be dead in less than a minute."

#define STABILIZED_MSG "The patient is stabilized."

#define DEAD_MSGS [\
    "Their time has expired.",\
    "They are no longer with us",\
    "Their time on this earth has expired",\
    "They should be 6 foot under",\
    "They have gone to meet their maker",\
    "They are pushing up daisies",\
    "They are an ex-soldier"\
]

#define CARDIAC_HEART_RATE 40
#define REVIVE_HEART_RATE (40 + floor (random [10, 15, 20]))

#define NORMAL_ACCURACY 100
#define MEDIC_ACCURACY 25
#define DOCTOR_ACCURACY 5

params ["_caller", "_target"];

private _bloodPressure = [_target] call FUNC(getBloodPressure);
_bloodPressure params [ "_bloodPressureLow", "_bloodPressureHigh"];
_bloodPressureLow = (_bloodPressureLow max 50) + floor (random [5, 10, 30]);
_bloodPressureHigh = (_bloodPressureHigh max 70) + floor (random [5, 10, 30]);

private _fnc_addToLog = {
    params ["_unit", "_message", "_arguments"];
    [_unit, "activity", _message, _arguments] call FUNC(addToLog);
    [_unit, "activity_view", _message, _arguments] call FUNC(addToLog);
};

if (_target getVariable [QGVAR(inReviveState), false]) exitWith {
    private _reviveStartTime = _target getVariable [QGVAR(reviveStartTime), 0];

    private _diagTimeAccuracy = NORMAL_ACCURACY;
    private _bloodLossMsg = BLOOD_LOSS_NORMAL_MSG;
    private _reviveTimeMsg = REVIVE_TIME_NORMAL_MSG;

    private _medicClass = _caller getVariable [
        QGVAR(medicClass), // Var name
        [0, 1] select (_caller getUnitTrait "medic") // <array> select <boolean/index>
    ];
    private _isMedic = _medicClass > 0;

    if (_isMedic) then {
        _diagTimeAccuracy = if (_medicClass > 1) then { DOCTOR_ACCURACY } else { MEDIC_ACCURACY };
        _bloodLossMsg = BLOOD_LOSS_MEDIC_MSG;
        _reviveTimeMsg = REVIVE_TIME_MEDIC_MSG;
    };

    private _stableCondition = [_target] call FUNC(isInStableCondition);

    _reviveStartTime = (if (_stableCondition) then {
        _reviveStartTime + floor (random [20, 40, 60])
    } else {
        private _bleedingRate = ([_target] call FUNC(getBloodLoss)) * 100;
        _reviveStartTime - (floor (random [_bleedingRate / 1.5, _bleedingRate, _bleedingRate * 1.5]) max 0)
    }) min CBA_missionTime;

    _target setVariable [QGVAR(reviveStartTime), _reviveStartTime];

    private _remainingReviveTime = GVAR(maxReviveTime) - (CBA_missionTime - _reviveStartTime);
    _timeleft = ((floor _remainingReviveTime) + (floor (random [_diagTimeAccuracy * -1, 0, _diagTimeAccuracy]))) max 1;
    if (_remainingReviveTime > 0) then {
        if !(_isMedic) then {
            if (_timeleft < 60) then {
                _reviveTimeMsg = REVIVE_TIME_LOW_NORMAL_MSG;
            } else {
                _timeleft = floor (_timeleft / 60);
            };
        } else {
            if (_timeleft <= 15) then {
                _reviveTimeMsg = REVIVE_TIME_LOW_MEDIC_MSG;
            };
        };
    } else {
        _reviveTimeMsg = selectRandom DEAD_MSGS;
    };

    private _nameCaller = [_caller] call EFUNC(common,getName);
    private _nameTarget = [_target] call EFUNC(common,getName);
    if (_stableCondition) then {
        [_target, _reviveTimeMsg, [_timeleft, _nameTarget]] call _fnc_addToLog;

        if (_isMedic) then {
            [_target, STABILIZED_MSG, []] call _fnc_addToLog;
    };

        if ((random 1) > 0.8) then {
            _target setVariable [QGVAR(inReviveState), nil, true];
            _target setVariable [QGVAR(heartRate), REVIVE_HEART_RATE];
            _target setVariable [QGVAR(bloodPressure), [_bloodPressureLow, _bloodPressureHigh]];
            [_target, false] call FUNC(setUnconscious);
        };
    } else {
        [_target, _bloodLossMsg, [_nameCaller, _nameTarget]] call _fnc_addToLog;
        [_target, _reviveTimeMsg, [_timeleft, _nameTarget]] call _fnc_addToLog;
    };

    true
};

if (GVAR(level) > 1 && {(random 1) >= 0.5}) then {
    _target setVariable [QGVAR(inCardiacArrest), nil,true];
    _target setVariable [QGVAR(heartRate), CARDIAC_HEART_RATE];
    _target setVariable [QGVAR(bloodPressure), [_bloodPressureLow, _bloodPressureHigh]];
    [_target, false] call FUNC(setUnconscious);
};

[_target, LSTRING(Activity_CPR), [[_caller, false, true] call EFUNC(common,getName)]] call _fnc_addToLog; // TODO expand message

true;
