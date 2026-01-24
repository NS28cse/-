% main_plot_figures.m - Generate figures for the report.

% Load results.
results_root = '../results';
reports_root = '../reports/figures';
mkdir(reports_root);
data = readtable(fullfile(results_root, 'master.tsv'), 'FileType', 'text', 'Delimiter', '\t');

unique_samples = unique(data.SampleName);

for s_idx = 1:length(unique_samples)
    sample_name = unique_samples{s_idx};
    sample_data = data(strcmp(data.SampleName, sample_name), :);

    % --- Figure 1: Stability Analysis ---
    figure('Color', 'w', 'Name', ['Stability - ', sample_name]);
    hold on;
    states_list = unique(sample_data.States);
    colors = gray(length(states_list) + 1); % Greyscale for report.

    for i = 1:length(states_list)
        st = states_list(i);
        lik_values = sort(sample_data.FinalLogLik(sample_data.States == st));
        plot(lik_values, 'Color', colors(i,:), 'LineWidth', 1.5, 'DisplayName', sprintf('States=%d', st));
    end
    xlabel('Trial Index (Sorted by Likelihood).');
    ylabel('Final Log Likelihood.');
    title(['Stability Analysis (', sample_name, ').']);
    legend('Location', 'southeast');
    grid on;
    saveas(gcf, fullfile(reports_root, [sample_name, '_fig1_stability.png']));

    % --- Figure 2: Learning Convergence ---
    figure('Color', 'w', 'Name', ['Convergence - ', sample_name]);
    hold on;
    for i = 1:length(states_list)
        st = states_list(i);
        % Get the best seed for this state count.
        state_rows = sample_data(sample_data.States == st, :);
        [~, best_idx] = max(state_rows.FinalLogLik);
        history_path = state_rows.HistoryPath{best_idx};
        
        hist = readtable(history_path, 'FileType', 'text', 'Delimiter', '\t');
        semilogy(hist.Step, hist.DError, 'Color', colors(i,:), 'LineWidth', 1.2, 'DisplayName', sprintf('States=%d', st));
    end
    xlabel('Iterations.');
    ylabel('Log Error (DError).');
    title(['Learning Convergence of Best Seeds (', sample_name, ').']);
    legend('Location', 'northeast');
    grid on;
    saveas(gcf, fullfile(reports_root, [sample_name, '_fig2_convergence.png']));

    % --- Figure 3: Model Selection (AIC/BIC) ---
    figure('Color', 'w', 'Name', ['Model Selection - ', sample_name]);
    best_results = [];
    for i = 1:length(states_list)
        st = states_list(i);
        state_rows = sample_data(sample_data.States == st, :);
        [max_lik, best_idx] = max(state_rows.FinalLogLik);
        best_results = [best_results; state_rows(best_idx, :)];
    end

    yyaxis left;
    plot(best_results.States, best_results.AIC, '-o', 'MarkerFaceColor', 'k', 'DisplayName', 'AIC');
    ylabel('AIC.');
    yyaxis right;
    plot(best_results.States, best_results.BIC, '--s', 'MarkerFaceColor', 'w', 'DisplayName', 'BIC');
    ylabel('BIC.');
    
    xlabel('Number of States.');
    title(['Model Selection Criteria (', sample_name, ').']);
    legend('Location', 'north');
    grid on;
    saveas(gcf, fullfile(reports_root, [sample_name, '_fig3_selection.png']));
end