function output = Optimizer(nAP, nED, compressionRatio, paramsCC, paramsAP, paramsED)
%
%

%% params init
% CC params: totalComputeResource, totalTransmitResource
% nparamsCC = 2;
% paramsCC = reshape(paramsCC, nCC, nparamsCC);
totalComputeResourceCC = paramsCC(:, 1);
totalTransmitResourceCC = paramsCC(:, 2);

% AP params: totalComputeResource, totalTransmitResource, nChilds
nparamsAP = 3;
paramsAP = reshape(paramsAP, [nAP, nparamsAP]);
paramsAP = [paramsAP, paramsAP*0];
totalComputeResourceAP = paramsAP(:, 1);
totalTransmitResourceAP = paramsAP(:, 2);
nChilds = round(paramsAP(:, 3)); % It's a double data
% generateSpeedEquivalentAP = paramsAP(:, 4);
% divisionPercentageEquivalentAP = paramsAP(:, 5);
% betaSum = paramsAP(:, 6);
childStartIdx = cumsum(paramsAP(:, 3)) - paramsAP(:, 3) + 1;

% ED params:    generateSpeedED, computeCapacityED, divisionPercentageED, transmitSpeedED,
%               computeCapacityAP, divisionPercentageAP, transmitSpeedAP,

nparamsED = 7;
paramsED = reshape(paramsED, [nED, nparamsED]);

generateSpeedED      = paramsED(:, 1);
computeCapacityED    = paramsED(:, 2);
divisionPercentageED = paramsED(:, 3);
transmitSpeedED      = paramsED(:, 4);
computeCapacityAP    = paramsED(:, 5);
divisionPercentageAP = paramsED(:, 6);
transmitSpeedAP      = paramsED(:, 7);


%% optimization
blocking = 0;
rho = compressionRatio;

% ED layer optimization
% full utilize the compute capacity of ED
divisionPercentageED = computeCapacityED ./ generateSpeedED;
transmitSpeedED = generateSpeedED .* (1 + (rho - 1) * divisionPercentageED );

for i = 1:nAP
    startIdx = childStartIdx(i);
    endIdx = startIdx + paramsAP(i, nChilds) -1;
    totalTransmitSpeedED = sum(transmitSpeedED(startIdx:endIdx));
    if(totalTransmitSpeedED > totalTransmitResourceAP(i))
        blocking = 1;
        [divisionPercentageED, transmitSpeedED] = ...
            BlockingOptimizerED(...
            totalTransmitResourceAP(i), ...
            compressionRatio, ...
            generateSpeedED(startIdx:endIdx), ...
            computeCapacityED(startIdx:endIdx)...
            );
    end
end

%%
% AP layer optimization
% params init
[generateSpeedEquivalentAP,...
    divisionPercentageEquivalentAP,...
    betaSum,...
    generateSpeedAP,...
    computeCapacityAP,...
    divisionPercentageAP,...
    transmitSpeedAP]...
    = InitApLayerParams(...
    nAP,...
    compressionRatio,...
    totalComputeResourceAP,...
    childStartIdx,...
    nChilds,...
    divisionPercentageED,...
    transmitSpeedED ...
    );

% judge if blocking
totalTransmitSpeedAP = sum(transmitSpeedAP);

if(totalTransmitSpeedAP > totalTransmitResourceCC)
    blocking = 1;
    [divisionPercentageED, divisionPercentageEquivalentAP, ~] = ...
        BlockingOptimizerAP(...
        nAP,...
        compressionRatio,...
        totalTransmitResourceCC,...
        generateSpeedEquivalentAP,...
        totalComputeResourceAP,...
        childStartIdx,...
        nChilds,...
        generateSpeedAP,...
        transmitSpeedED,...
        generateSpeedED,...
        computeCapacityED...
        );
    
    [~,...
        ~,...
        ~,...
        generateSpeedAP,...
        computeCapacityAP,...
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
    
    % updateDivisionPercentageAP using divisionPercentageEquivalentAP
    for i = 1:nAP
        startIdx = childStartIdx(i);
        endIdx = startIdx + nChilds(i) -1;
        divisionPercentageAP(startIdx:endIdx) =  divisionPercentageAP(startIdx:endIdx)*0 + divisionPercentageEquivalentAP(i);
    end
    transmitSpeedAP = ...
        generateSpeedAP .* (1 + (rho - 1) * divisionPercentageAP)...
        + betaAP;
end

%% CC layer optimization
generateSpeedCC = transmitSpeedAP .* (1 - divisionPercentageAP)...
    ./ (1 + (rho - 1) * divisionPercentageAP + (rho * divisionPercentageED / (1 - divisionPercentageED)) );
computeCapacityCC = generateSpeedCC;

% judge CC if blocking
computeBlocking = sum(sum(computeCapacityCC)) > totalComputeResourceCC;
transmitBlocking = sum(sum(transmitSpeedAP)) > totalTransmitResourceCC;
if(computeBlocking || transmitBlocking)
    blocking = 1;
    [divisionPercentageED, ~, divisionPercentageAP] = ...
        BlockingOptimizerCC(...
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
        );
end

if(~blocking)
    %% Non-blocking optimization
    [divisionPercentageED, transmitSpeedED, computeCapacityAP, divisionPercentageAP, transmitSpeedAP, computeCapacityCC] = ...
        NonBlockingOptimizer(...
        nAP,...
        nED,...
        childStartIdx,...
        nChilds,...
        compressionRatio,...
        totalTransmitResourceCC, ...
        totalComputeResourceCC,...
        totalTransmitResourceAP,...
        totalComputeResourceAP,...
        computeCapacityED,...
        generateSpeedED...
        )
    
end
output = [divisionPercentageED, transmitSpeedED, computeCapacityAP, divisionPercentageAP, transmitSpeedAP, computeCapacityCC];
nOutput = 5;
output = reshape(output, nED * nOutput);
end


