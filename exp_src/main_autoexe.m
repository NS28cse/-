% main_autoexe.m - Automation script for HMM experiments.

% Initialize parameters.
samples = {'sample0', 'sample1', 'sample2', 'sample3', 'sample4'};
states_list = 2:6;
num_seeds = 50;
bin_dir = '../bin';
results_root = '../results';

% Create master table to store results.
master_file = fullfile(results_root, 'master.tsv');
master_fid = fopen(master_file, 'w');
fprintf(master_fid, 'SampleName\tStates\tSeed\tSymbols\tTotalLen\tFinalLogLik\tIterations\tParams\tAIC\tBIC\tModelPath\tHistoryPath\n');
fclose(master_fid);

for s_idx = 1:length(samples)
    sample_name = samples{s_idx};
    fprintf('Processing sample: %s\n', sample_name);

    % Create output directories.
    output_dir = fullfile(results_root, sample_name);
    mkdir(fullfile(output_dir, 'models'));
    mkdir(fullfile(output_dir, 'viterbi'));
    mkdir(fullfile(output_dir, 'history'));

    best_loglik = -inf;
    best_seed = 1;

    for states = states_list
        for seed = 1:num_seeds
            % Execute BaumWelch.exe.
            % Command: [SampleName] [OutputDir] [States] [Seed]
            cmd = sprintf('"%s/BaumWelch.exe" %s %s %d %d', bin_dir, sample_name, output_dir, states, seed);
            [status, cmdout] = system(cmd);
            
            if status ~= 0
                fprintf('Error executing BaumWelch for %s, S:%d, Seed:%d.\n', sample_name, states, seed);
                continue;
            end

            % Parse HISTORY and RESULTS from standard output.
            lines = splitlines(cmdout);
            history_data = [];
            results_data = struct();

            history_file = fullfile(output_dir, 'history', sprintf('history_s%d_%d.tsv', states, seed));
            h_fid = fopen(history_file, 'w');
            fprintf(h_fid, 'Step\tLogLik\tDError\n');

            for l = 1:length(lines)
                if startsWith(lines{l}, 'HISTORY')
                    % Parse: HISTORY [Step] [LogLik] [DError]
                    tokens = split(lines{l});
                    fprintf(h_fid, '%s\t%s\t%s\n', tokens{2}, tokens{3}, tokens{4});
                elseif startsWith(lines{l}, 'RESULTS')
                    % Parse: RESULTS [SampleName] [States] [Seed] [Symbols] [TotalLen] [FinalLogLik] [Iterations]
                    tokens = split(lines{l});
                    results_data.sample = tokens{2};
                    results_data.states = str2double(tokens{3});
                    results_data.seed = str2double(tokens{4});
                    results_data.symbols = str2double(tokens{5});
                    results_data.total_len = str2double(tokens{6});
                    results_data.final_loglik = str2double(tokens{7});
                    results_data.iterations = str2double(tokens{8});
                end
            end
            fclose(h_fid);

            % Calculate Information Criteria (AIC/BIC).
            % Number of parameters = States^2 + States * Symbols + (States - 1).
            k = results_data.states^2 + results_data.states * results_data.symbols + (results_data.states - 1);
            n = results_data.total_len;
            L = results_data.final_loglik;
            aic = 2 * k - 2 * L;
            bic = k * log(n) - 2 * L;
            model_path = fullfile(output_dir, 'models', sprintf('markov_output_s%d_%d.txt', states, seed));

            % Append to master.tsv.
            master_fid = fopen(master_file, 'a');
            fprintf(master_fid, '%s\t%d\t%d\t%d\t%d\t%.6f\t%d\t%d\t%.6f\t%.6f\t%s\t%s\n', ...
                sample_name, states, seed, results_data.symbols, n, L, results_data.iterations, k, aic, bic, model_path, history_file);
            fclose(master_fid);

            % Track best seed for Viterbi and model selection.
            if L > best_loglik
                best_loglik = L;
                best_seed = seed;
            end
        end

        % Execute Viterbi.exe for the best model of the current state count.
        best_model = fullfile(output_dir, 'models', sprintf('markov_output_s%d_%d.txt', states, best_seed));
        viterbi_cmd = sprintf('"%s/Viterbi.exe" %s %s %s', bin_dir, sample_name, output_dir, best_model);
        system(viterbi_cmd);
    end
end