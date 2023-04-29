using Statistics

function model_step!(model)
    model_action_eliminate!(model)
    model_action_summarize!(model)
end

function model_action_summarize!(model)
    #
    # Percentage of total rice energy
    #
    pct_rices = sum(model.rice_map .* model.flower_mask) / sum(model.flower_mask)

    #
    # Collect BPH population statistics
    #
    num_eggs = 0
    num_nymphs = 0
    num_macros = 0
    num_brachys = 0
    num_females = 0
    for (_, agent) in (model.agents)
        stage = agent.stage
        if agent.gender == Female && stage != Egg
            num_females = num_females + 1
        end
        if stage == Egg
            num_eggs += 1
        elseif stage == Nymph
            num_nymphs += 1
        elseif agent.form == Brachy
            num_brachys += 1
        else
            num_macros += 1
        end
    end

    #
    # Save statistics
    #
    model.num_eggs = num_eggs
    model.num_nymphs = num_nymphs
    model.num_macros = num_macros
    model.num_brachys = num_brachys
    model.num_females = num_females
    model.pct_rices = pct_rices
end

function model_action_eliminate!(model)
    for pos in model.eliminate_positions
        pos = Tuple(pos)
        if isempty(pos, model)
            continue
        end
        for agent in agents_in_position(pos, model)
            pr = sqrt(max(zero(Float32),
                          (1 - agent.energy) * model.pr_eliminate_map[pos...]))
            if rand(model.rng, Float32) < pr
                kill_agent!(agent, model)
            end
        end
    end
end
