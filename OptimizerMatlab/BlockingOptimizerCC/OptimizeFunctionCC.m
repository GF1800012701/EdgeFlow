function f = OptimizeFunctionCC(...
    alpha,...
    nAP,...
    compressionRatio,...
    totalComputeResourceCC,...
    totalComputeResourceAP,...
    childStartIdx,...
    nChilds,...
    transmitSpeedAP,...
    transmitSpeedED,....
    generateSpeedED,...
    computeCapacityED...
    )

divisionPercentageED = ComputeDivisionPercentageED(alpha, computeCapacityED, generateSpeedED);
[generateSpeedEquivalentAP,...
    ~,...
    ~,...
    ~,...
    ~,...
    ~,...
    ~]...
    = InitApLayerParams(...
    nAP,...
    compressionRatio,...
    totalComputeResourceAP,...
    childStartIdx,...
    nChilds,...
    divisionPercentageED,...
    transmitSpeedED ...
    );


kalpha = generateSpeedED(1) / computeCapacityED(1) * alpha;
divisionPercentageEquivalentAP = ...
    ComputeDivisionPercentageEquivalentAP(...
    kalpha, ...
    generateSpeedEquivalentAP, ...
    totalComputeResourceAP...
    );

divisionPercentageAP = transmitSpeedAP*0;
for i = 1:nAP
    startIdx = childStartIdx(i);
    endIdx = startIdx + nChilds(i) -1;
    divisionPercentageAP(startIdx:endIdx) =  divisionPercentageAP(startIdx:endIdx)*0 + divisionPercentageEquivalentAP(i);
end

generateSpeedCC = transmitSpeedAP .* (1 - divisionPercentageAP)...
    ./ (1 + (compressionRatio - 1) * divisionPercentageAP + (compressionRatio * divisionPercentageED / (1 - divisionPercentageED)) );
computeCapacityCC = generateSpeedCC;

f = abs( sum(sum(computeCapacityCC))/totalComputeResourceCC - kalpha );

end
