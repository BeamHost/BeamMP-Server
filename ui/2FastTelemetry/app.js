// File: ui/2FastTelemetry/app.js
// AngularJS HUD for 2FastTelemetry

var app = angular.module('twofast', []);

app.controller('HudCtrl', ['$scope', '$timeout', function($scope, $timeout) {
    $scope.state = {
        lapTime: 0,
        bestLap: 0,
        delta: 0,
        lap: 0,
        totalLaps: null,
        sector: 1,
        splitMs: 0,
        countdown: null,
        standings: []
    };

    function applyUpdate(data) {
        if (data.lapTime !== undefined) $scope.state.lapTime = data.lapTime / 1000;
        if (data.bestLap !== undefined) $scope.state.bestLap = data.bestLap / 1000;
        if (data.delta !== undefined) $scope.state.delta = data.delta / 1000;
        if (data.sector) $scope.state.sector = data.sector;
        if (data.splitMs) $scope.state.splitMs = data.splitMs / 1000;
        if (data.lapComplete) $scope.state.lap = ($scope.state.lap || 0) + 1;
        if (data.laps) $scope.state.lap = data.laps;
        if (data.totalLaps) $scope.state.totalLaps = data.totalLaps;
        if (data.countdown !== undefined) $scope.state.countdown = data.countdown;
        if (data.standings) $scope.state.standings = data.standings;
        $scope.$applyAsync();
    }

    // BeamMP client bridge
    if (typeof mp !== 'undefined' && mp.events && mp.events.on) {
        mp.events.on('TwoFast:update', function(payload) {
            applyUpdate(payload || {});
        });
        mp.events.on('TwoFast:raceStart', function(payload) {
            $scope.state.totalLaps = payload && payload.laps;
        });
    } else {
        console.log('mp.events bridge missing; running in mock mode');
    }
}]);
