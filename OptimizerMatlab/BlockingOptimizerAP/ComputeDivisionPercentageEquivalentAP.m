function divisionPercentageEquivalentAP = ...
    ComputeDivisionPercentageEquivalentAP(...
        kalpha, ...
        generateSpeedEquivalentAP, ...
        totalComputeResourceAP...
    )

divisionPercentageEquivalentAP =kalpha * totalComputeResourceAP ./ generateSpeedEquivalentAP;

end