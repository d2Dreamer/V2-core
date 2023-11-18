module baptswap_v2::router_v2 {
    use aptos_framework::aptos_coin::{AptosCoin};
    use aptos_framework::coin;
    use aptos_std::type_info;
    use baptswap::swap_utils;
    use baptswap_v2::swap_v2;
    use std::signer;

    //
    // Errors.
    //

    // Output amount is less than required
    const E_OUTPUT_LESS_THAN_MIN: u64 = 0;
    // Require Input amount is more than max limit
    const E_INPUT_MORE_THAN_MAX: u64 = 1;
    // Insufficient X
    const E_INSUFFICIENT_X_AMOUNT: u64 = 2;
    // Insufficient Y
    const E_INSUFFICIENT_Y_AMOUNT: u64 = 3;
    // Pair is created
    const E_PAIR_CREATED: u64 = 40;
    // Pair is not created
    const E_PAIR_NOT_CREATED: u64 = 4;
    // Pool already created
    const E_POOL_EXISTS: u64 = 5;
    // Pool not created
    const E_POOL_NOT_CREATED: u64 = 6;

    // Create a Pair from 2 Coins
    // Should revert if the pair is already created
    public entry fun create_pair<X, Y>(
        sender: &signer,
    ) {
        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::create_pair<X, Y>(sender);
        } else {
            swap_v2::create_pair<Y, X>(sender);
        }
    }

    // Toggle individual token fee; 
    // this includes team/rewards/and part of liquidity fee
    public entry fun initialize_fee_on_transfer<CoinType>(
        sender: &signer,
        liquidity_fee: u128,
        rewards_fee: u128,
        team_fee: u128
    ) {
        swap_v2::init_fee_on_transfer<CoinType>(sender, liquidity_fee, rewards_fee, team_fee);
    }

    public entry fun register_token_in_a_pair<CoinType, X, Y>(sender: &signer){
        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::add_fee_on_transfer_in_pair<CoinType, X, Y>(sender);
        } else {
            swap_v2::add_fee_on_transfer_in_pair<CoinType, Y, X>(sender);
        }
    }

    public entry fun create_rewards_pool<X, Y>(
        sender: &signer,
        is_x_staked: bool
    ) {
        assert!(((swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>())), E_PAIR_NOT_CREATED);
        assert!(!((swap_v2::is_pool_created<X, Y>() || swap_v2::is_pool_created<Y, X>())), E_POOL_EXISTS);

        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::init_rewards_pool<X, Y>(sender, is_x_staked);
        } else {
            swap_v2::init_rewards_pool<Y, X>(sender, !is_x_staked);
        }
    }

    public entry fun stake_tokens_in_pool<X, Y>(
        sender: &signer,
        amount: u64
    ) {
        assert!(((swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>())), E_PAIR_NOT_CREATED);
        assert!(((swap_v2::is_pool_created<X, Y>() || swap_v2::is_pool_created<Y, X>())), E_POOL_NOT_CREATED);

        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::stake_tokens<X, Y>(sender, amount);
        } else {
            swap_v2::stake_tokens<Y, X>(sender, amount);
        }
    }


    public entry fun unstake_tokens_from_pool<X, Y>(
        sender: &signer,
        amount: u64
    ) {
        assert!(((swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>())), E_PAIR_NOT_CREATED);
        assert!(((swap_v2::is_pool_created<X, Y>() || swap_v2::is_pool_created<Y, X>())), E_POOL_NOT_CREATED);

        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::unstake_tokens<X, Y>(sender, amount);
        } else {
            swap_v2::unstake_tokens<Y, X>(sender, amount);
        }
    }

    public entry fun claim_rewards_from_pool<X, Y>(
        sender: &signer
    ) {
        assert!(((swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>())), E_PAIR_NOT_CREATED);
        assert!(((swap_v2::is_pool_created<X, Y>() || swap_v2::is_pool_created<Y, X>())), E_POOL_NOT_CREATED);

        if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::claim_rewards<X, Y>(sender);
        } else {
            swap_v2::claim_rewards<Y, X>(sender);
        }
    }

    // Add Liquidity, create pair if it's needed
    public entry fun add_liquidity<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) {
        if (!(swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>())) {
            create_pair<X, Y>(sender);
        };

        let amount_x;
        let amount_y;
        let _lp_amount;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y, _lp_amount) = swap_v2::add_liquidity<X, Y>(sender, amount_x_desired, amount_y_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x, _lp_amount) = swap_v2::add_liquidity<Y, X>(sender, amount_y_desired, amount_x_desired);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        };
    }

    fun assert_pair_is_not_created<X, Y>(){
        assert!(!swap_v2::is_pair_created<X, Y>() || !swap_v2::is_pair_created<Y, X>(), E_PAIR_CREATED);
    }

    fun assert_pair_is_created<X, Y>(){
        assert!(swap_v2::is_pair_created<X, Y>() || swap_v2::is_pair_created<Y, X>(), E_PAIR_NOT_CREATED);
    }

    // TODO: if a pair not created, find route; should be used in swap 

    // Remove Liquidity
    public entry fun remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64
    ) {
        assert_pair_is_created<X, Y>();
        let amount_x;
        let amount_y;
        if (swap_utils::sort_token_type<X, Y>()) {
            (amount_x, amount_y) = swap_v2::remove_liquidity<X, Y>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        } else {
            (amount_y, amount_x) = swap_v2::remove_liquidity<Y, X>(sender, liquidity);
            assert!(amount_x >= amount_x_min, E_INSUFFICIENT_X_AMOUNT);
            assert!(amount_y >= amount_y_min, E_INSUFFICIENT_Y_AMOUNT);
        }
    }

    fun add_swap_event_with_address_internal<X, Y>(
        sender_addr: address,
        amount_x_in: u64,
        amount_y_in: u64,
        amount_x_out: u64,
        amount_y_out: u64
    ) {
        if (swap_utils::sort_token_type<X, Y>()){
            swap_v2::add_swap_event_with_address<X, Y>(sender_addr, amount_x_in, amount_y_in, amount_x_out, amount_y_out);
        } else {
            swap_v2::add_swap_event_with_address<Y, X>(sender_addr, amount_y_in, amount_x_in, amount_y_out, amount_x_out);
        }
    }

    fun add_swap_event_internal<X, Y>(
        sender: &signer,
        amount_x_in: u64,
        amount_y_in: u64,
        amount_x_out: u64,
        amount_y_out: u64
    ) {
        let sender_addr = signer::address_of(sender);
        add_swap_event_with_address_internal<X, Y>(sender_addr, amount_x_in, amount_y_in, amount_x_out, amount_y_out);
    }

    // Swap exact input amount of X to maxiumin possible amount of Y
    public entry fun swap_exact_input<X, Y>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64,
    ) {
        assert_pair_is_created<X, Y>();
        let y_out = if (swap_utils::sort_token_type<X, Y>()) {
            swap_v2::swap_exact_x_to_y<X, Y>(sender, x_in, signer::address_of(sender))
        } else {
            swap_v2::swap_exact_y_to_x<Y, X>(sender, x_in, signer::address_of(sender))
        };
        assert!(y_out >= y_min_out, E_OUTPUT_LESS_THAN_MIN);
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
    }

    // Swap miniumn possible amount of X to exact output amount of Y
    public entry fun swap_exact_output<X, Y>(
        sender: &signer,
        y_out: u64,
        x_max_in: u64,
    ) {
        assert_pair_is_created<X, Y>();
        let x_in = if (swap_utils::sort_token_type<X, Y>()) {
            let (rin, rout, _) = swap_v2::token_reserves<X, Y>();
            // if output amount reserve is 0; use APT instead of Y
            if (rout == 0) {
                assert!(type_info::type_of<X>() != type_info::type_of<AptosCoin>(), 1);
                let (rin, aptrout, _) = swap_v2::token_reserves<X, AptosCoin>();

                let total_fees = swap_v2::token_fees<X, AptosCoin>();
                let amount_in = swap_utils::get_amount_in(y_out, rin, aptrout, total_fees);

                swap_v2::swap_x_to_exact_y<X, AptosCoin>(sender, amount_in, y_out, signer::address_of(sender));
            };

            let total_fees = swap_v2::token_fees<X, Y>();
            let amount_in = swap_utils::get_amount_in(y_out, rin, rout, total_fees);
            
            swap_v2::swap_x_to_exact_y<X, Y>(sender, amount_in, y_out, signer::address_of(sender))
        } else {
            let (rout, rin, _) = swap_v2::token_reserves<Y, X>();
            
            if (rout == 0) {
                assert!(type_info::type_of<X>() != type_info::type_of<AptosCoin>(), 1);
                let (rin, aptrout, _) = swap_v2::token_reserves<Y, AptosCoin>();

                let total_fees = swap_v2::token_fees<Y, AptosCoin>();
                let amount_in = swap_utils::get_amount_in(y_out, rin, aptrout, total_fees);

                swap_v2::swap_y_to_exact_x<Y, AptosCoin>(sender, amount_in, y_out, signer::address_of(sender));
            };

            let total_fees = swap_v2::token_fees<Y, X>();
            let amount_in = swap_utils::get_amount_in(y_out, rin, rout, total_fees);
            swap_v2::swap_y_to_exact_x<Y, X>(sender, amount_in, y_out, signer::address_of(sender))
        };
        assert!(x_in <= x_max_in, E_INPUT_MORE_THAN_MAX);
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);
    }

    fun get_intermediate_output<X, Y>(is_x_to_y: bool, x_in: coin::Coin<X>): coin::Coin<Y> {
        if (is_x_to_y) {
            let (x_out, y_out) = swap_v2::swap_exact_x_to_y_direct<X, Y>(x_in);
            coin::destroy_zero(x_out);
            y_out
        }
        else {
            let (y_out, x_out) = swap_v2::swap_exact_y_to_x_direct<Y, X>(x_in);
            coin::destroy_zero(x_out);
            y_out
        }
    }

    public fun swap_exact_x_to_y_direct_external<X, Y>(x_in: coin::Coin<X>): coin::Coin<Y> {
        assert_pair_is_created<X, Y>();
        let x_in_amount = coin::value(&x_in);
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        let y_out = get_intermediate_output<X, Y>(is_x_to_y, x_in);
        let y_out_amount = coin::value(&y_out);
        add_swap_event_with_address_internal<X, Y>(@zero, x_in_amount, 0, 0, y_out_amount);
        y_out
    }

    fun get_intermediate_output_x_to_exact_y<X, Y>(is_x_to_y: bool, x_in: coin::Coin<X>, amount_out: u64): coin::Coin<Y> {
        if (is_x_to_y) {
            let (x_out, y_out) = swap_v2::swap_x_to_exact_y_direct<X, Y>(x_in, amount_out);
            coin::destroy_zero(x_out);
            y_out
        }
        else {
            let (y_out, x_out) = swap_v2::swap_y_to_exact_x_direct<Y, X>(x_in, amount_out);
            coin::destroy_zero(x_out);
            y_out
        }
    }

    fun get_amount_in_internal<X, Y>(is_x_to_y:bool, y_out_amount: u64): u64 {
        if (is_x_to_y) {
            let (rin, rout, _) = swap_v2::token_reserves<X, Y>();
            let total_fees = swap_v2::token_fees<X, Y>();
            swap_utils::get_amount_in(y_out_amount, rin, rout, total_fees)
        } else {
            let (rout, rin, _) = swap_v2::token_reserves<Y, X>();
            let total_fees = swap_v2::token_fees<Y, X>();
            swap_utils::get_amount_in(y_out_amount, rin, rout, total_fees)
        }
    } 

    public fun get_amount_in<X, Y>(y_out_amount: u64): u64 {
        assert_pair_is_created<X, Y>();
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        get_amount_in_internal<X, Y>(is_x_to_y, y_out_amount)
    }

    public fun swap_x_to_exact_y_direct_external<X, Y>(x_in: coin::Coin<X>, y_out_amount:u64): (coin::Coin<X>, coin::Coin<Y>) {
        assert_pair_is_created<X, Y>();
        let is_x_to_y = swap_utils::sort_token_type<X, Y>();
        let x_in_withdraw_amount = get_amount_in_internal<X, Y>(is_x_to_y, y_out_amount);
        let x_in_amount = coin::value(&x_in);
        assert!(x_in_amount >= x_in_withdraw_amount, E_INSUFFICIENT_X_AMOUNT);
        let x_in_left = coin::extract(&mut x_in, x_in_amount - x_in_withdraw_amount);
        let y_out = get_intermediate_output_x_to_exact_y<X, Y>(is_x_to_y, x_in, y_out_amount);
        add_swap_event_with_address_internal<X, Y>(@zero, x_in_withdraw_amount, 0, 0, y_out_amount);
        (x_in_left, y_out)
    }

    public entry fun register_lp<X, Y>(sender: &signer) {
        swap_v2::register_lp<X, Y>(sender);
    }

    public entry fun register_token<X>(sender: &signer) {
        coin::register<X>(sender);
    }
}