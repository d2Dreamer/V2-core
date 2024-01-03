module baptswap_v2dot1::router_v2dot1 {

    use aptos_framework::aptos_coin::{AptosCoin as APT};
    use aptos_framework::coin;

    use baptswap_v2::swap_v2;
    use baptswap_v2::router_v2;

    use baptswap_v2dot1::errors_v2dot1;
    use baptswap_v2dot1::stake_v2dot1;
    use baptswap_v2dot1::swap_utils_v2dot1;
    use baptswap_v2dot1::swap_v2dot1;

    use std::signer;

    use mau::MAU::MAU;
    use other_coins::asset::{USDC, USDT, WETH};

    // Create a Pair from 2 coins
    // Should revert if the pair is already created
    public entry fun create_pair<X, Y>(
        sender: &signer,
    ) {
        if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            swap_v2dot1::create_pair<X, Y>(sender);
        } else {
            swap_v2dot1::create_pair<Y, X>(sender);
        }
    }

    // Add fee on transfer to a pair; callable only by owners of X or Y
    public entry fun register_fee_on_transfer_in_a_pair<CoinType, X, Y>(sender: &signer) {
        if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            swap_v2dot1::add_fee_on_transfer_in_pair<CoinType, X, Y>(sender);
            stake_v2dot1::create_pool<CoinType, X, Y>(sender, true);
        } else {
            swap_v2dot1::add_fee_on_transfer_in_pair<CoinType, Y, X>(sender);
            stake_v2dot1::create_pool<CoinType, Y, X>(sender, true);
        }
    }

    public entry fun stake_tokens_in_pool<X, Y>(
        sender: &signer,
        amount: u64
    ) {
        assert!(swap_v2dot1::is_pair_created<X, Y>() || swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
        assert!(stake_v2dot1::is_pool_created<X, Y>(), errors_v2dot1::pool_not_created());
        stake_v2dot1::deposit<X, Y>(sender, amount);
    }

    public entry fun unstake_tokens_from_pool<X, Y>(
        sender: &signer,
        amount: u64
    ) {
        assert!(swap_v2dot1::is_pair_created<X, Y>() || swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
        assert!(stake_v2dot1::is_pool_created<X, Y>(), errors_v2dot1::pool_not_created());
        stake_v2dot1::withdraw<X, Y>(sender, amount);
    }

    public entry fun claim_rewards_from_pool<X, Y>(sender: &signer) {
        assert!(swap_v2dot1::is_pair_created<X, Y>() || swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
        assert!(stake_v2dot1::is_pool_created<X, Y>(), errors_v2dot1::pool_not_created());
        stake_v2dot1::claim_rewards<X, Y>(sender);
    }

    // Add Liquidity, create pair if it's needed
    public entry fun add_liquidity<X, Y>(
        sender: &signer,
        amount_x_desired: u64,
        amount_y_desired: u64,
        amount_x_min: u64,
        amount_y_min: u64,
    ) {
        if (!(swap_v2dot1::is_pair_created<X, Y>() || swap_v2dot1::is_pair_created<Y, X>())) {
            create_pair<X, Y>(sender);
        };

        let amount_x;
        let amount_y;
        let _lp_amount;
        if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            (amount_x, amount_y, _lp_amount) = swap_v2dot1::add_liquidity<X, Y>(sender, amount_x_desired, amount_y_desired);
            assert!(amount_x >= amount_x_min, errors_v2dot1::insufficient_x_amount());
            assert!(amount_y >= amount_y_min, errors_v2dot1::insufficient_y_amount());
        } else {
            (amount_y, amount_x, _lp_amount) = swap_v2dot1::add_liquidity<Y, X>(sender, amount_y_desired, amount_x_desired);
            assert!(amount_x >= amount_x_min, errors_v2dot1::insufficient_x_amount());
            assert!(amount_y >= amount_y_min, errors_v2dot1::insufficient_y_amount());
        };
    }

    // Remove Liquidity
    public entry fun remove_liquidity<X, Y>(
        sender: &signer,
        liquidity: u64,
        amount_x_min: u64,
        amount_y_min: u64
    ) {
        let amount_x;
        let amount_y;
        if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            assert!(swap_v2dot1::is_pair_created<X, Y>(), errors_v2dot1::pair_not_created());
            (amount_x, amount_y) = swap_v2dot1::remove_liquidity<X, Y>(sender, liquidity);
            assert!(amount_x >= amount_x_min, errors_v2dot1::insufficient_x_amount());
            assert!(amount_y >= amount_y_min, errors_v2dot1::insufficient_y_amount());
        } else {
            assert!(swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
            (amount_y, amount_x) = swap_v2dot1::remove_liquidity<Y, X>(sender, liquidity);
            assert!(amount_x >= amount_x_min, errors_v2dot1::insufficient_x_amount());
            assert!(amount_y >= amount_y_min, errors_v2dot1::insufficient_y_amount());
        }
    }

    fun add_swap_event_with_address_internal<X, Y>(
        sender_addr: address,
        amount_x_in: u64,
        amount_y_in: u64,
        amount_x_out: u64,
        amount_y_out: u64
    ) {
        if (swap_utils_v2dot1::sort_token_type<X, Y>()){
            swap_v2dot1::add_swap_event_with_address<X, Y>(sender_addr, amount_x_in, amount_y_in, amount_x_out, amount_y_out);
        } else {
            swap_v2dot1::add_swap_event_with_address<Y, X>(sender_addr, amount_y_in, amount_x_in, amount_y_out, amount_x_out);
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
        y_min_out: u64
    ) {
        swap_exact_input_internal<X, Y>(sender, x_in, y_min_out);
    }

    fun swap_exact_input_internal<X, Y>(sender: &signer, x_in: u64, y_min_out: u64): u64 {
        let y_out = if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            assert!(swap_v2dot1::is_pair_created<X, Y>(), errors_v2dot1::pair_not_created());
            swap_v2dot1::swap_exact_x_to_y<X, Y>(sender, x_in, signer::address_of(sender))
        } else {
            assert!(swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
            swap_v2dot1::swap_exact_y_to_x<Y, X>(sender, x_in, signer::address_of(sender))
        };
        assert!(y_out >= y_min_out, errors_v2dot1::output_less_than_min());
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);

        y_out
    }

    // multi-hop
    // swap X for Y while pair<X, Y> doesn't exist, intermidiate token is Z
    public fun multi_hop_exact_input<X, Y, Z>(sender: &signer, x_in: u64, y_min_out: u64) {
        // if <X,Y> pair is created, swap X for Y
        if (swap_v2dot1::is_pair_created<X, Y>()) { swap_exact_input<X, Y>(sender, x_in, y_min_out) }
        else {
            let z_in = swap_exact_input_internal<X, Z>(sender, x_in, 0);    // TODO: should not be 0
            swap_exact_input_internal<Z, Y>(sender, z_in, y_min_out);
        }
    }

    public entry fun swap_exact_input_with_one_intermediate_coin<X, Y, Z>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64
    ) { multi_hop_exact_input<X, Y, Z>(sender, x_in, y_min_out); }

    // Z is APT
    public entry fun swap_exact_input_with_apt_as_intermidiate<X, Y>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64
    ) { swap_exact_input_with_one_intermediate_coin<X, Y, APT>( sender, x_in, y_min_out) }
        
    // TODO: Z is BAPT

    // TODO: Z is USDC

    // TODO: not tested
    public entry fun swap_exact_input_with_two_intermediate_coins<X, Y, Z, W>(
        sender: &signer,
        x_in: u64,
        y_min_out: u64
    ) {
        let z_in = swap_exact_input_internal<X, Z>(sender, x_in, 0);    // TODO: should not be 0
        let w_in = swap_exact_input_internal<Z, W>(sender, z_in, 0);    // TODO: should not be 0
        swap_exact_input_internal<W, Y>(sender, w_in, y_min_out);
    }

    // Swap miniumn possible amount of X to exact output amount of Y
    public entry fun swap_exact_output<X, Y>(sender: &signer, y_out: u64, x_max_in: u64) {
        swap_exact_output_internal<X, Y>(sender, y_out, x_max_in);
    }

    fun swap_exact_output_internal<X, Y>(sender: &signer, y_out: u64, x_max_in: u64): u64 {
        let x_in = if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            assert!(swap_v2dot1::is_pair_created<X, Y>(), errors_v2dot1::pair_not_created());
            let (rin, rout, _) = swap_v2dot1::token_reserves<X, Y>();
            let amount_in = swap_utils_v2dot1::get_amount_in(y_out, rin, rout, swap_v2dot1::liquidity_fee<X, Y>());
            swap_v2dot1::swap_x_to_exact_y<X, Y>(sender, amount_in, y_out, signer::address_of(sender))
        } else {
            assert!(swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
            let (rout, rin, _) = swap_v2dot1::token_reserves<Y, X>();
            let amount_in = swap_utils_v2dot1::get_amount_in(y_out, rin, rout, swap_v2dot1::liquidity_fee<Y, X>());
            swap_v2dot1::swap_y_to_exact_x<Y, X>(sender, amount_in, y_out, signer::address_of(sender))
        };
        assert!(x_in <= x_max_in, errors_v2dot1::input_more_than_max());
        add_swap_event_internal<X, Y>(sender, x_in, 0, 0, y_out);

        x_in
    }

    fun get_amount_in_internal<X, Y>(is_x_to_y:bool, y_out_amount: u64): u64 {
        if (is_x_to_y) {
            let (rin, rout, _) = swap_v2dot1::token_reserves<X, Y>();
            swap_utils_v2dot1::get_amount_in(y_out_amount, rin, rout, swap_v2dot1::liquidity_fee<X, Y>())
        } else {
            let (rout, rin, _) = swap_v2dot1::token_reserves<Y, X>();
            swap_utils_v2dot1::get_amount_in(y_out_amount, rin, rout, swap_v2dot1::liquidity_fee<Y, X>())
        }
    } 

    public fun get_amount_in<X, Y>(y_out_amount: u64): u64 {
        assert!(swap_v2dot1::is_pair_created<X, Y>(), errors_v2dot1::pair_not_created());
        let is_x_to_y = swap_utils_v2dot1::sort_token_type<X, Y>();
        get_amount_in_internal<X, Y>(is_x_to_y, y_out_amount)
    }

    public entry fun register_lp<X, Y>(sender: &signer) {
        swap_v2dot1::register_lp<X, Y>(sender);
    }

    public entry fun register_token<X>(sender: &signer) {
        coin::register<X>(sender);
    }

    // updates dex fee given a tier
    public entry fun update_fee_tier<Tier, X, Y>(signer_ref: &signer) {
        if (swap_utils_v2dot1::sort_token_type<X, Y>()) {
            assert!(swap_v2dot1::is_pair_created<X, Y>(), errors_v2dot1::pair_not_created());
            swap_v2dot1::update_fee_tier<Tier, X, Y>(signer_ref);
        } else {
            assert!(swap_v2dot1::is_pair_created<Y, X>(), errors_v2dot1::pair_not_created());
            swap_v2dot1::update_fee_tier<Tier, Y, X>(signer_ref);
        }
    }

    // merge to v2.1 
    public entry fun merge_to_v2dot1(signer_ref: &signer) {
        if (swap_utils_v2dot1::sort_token_type<APT, MAU>()) {
            merge<APT, MAU>(signer_ref);
        } else {
            merge<MAU, APT>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<APT, USDC>()) {
            merge<APT, USDC>(signer_ref);
        } else {
            merge<USDC, APT>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<APT, USDT>()) {
            merge<APT, USDT>(signer_ref);
        } else {
            merge<USDT, APT>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<APT, WETH>()) {
            merge<APT, WETH>(signer_ref);
        } else {
            merge<WETH, APT>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<MAU, USDC>()) {
            merge<MAU, USDC>(signer_ref);
        } else {
            merge<USDC, MAU>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<MAU, USDT>()) {
            merge<MAU, USDT>(signer_ref);
        } else {
            merge<USDT, MAU>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<MAU, WETH>()) {
            merge<MAU, WETH>(signer_ref);
        } else {
            merge<WETH, MAU>(signer_ref);
        };
        if (swap_utils_v2dot1::sort_token_type<USDC, USDT>()) {
            merge<USDC, USDT>(signer_ref);
        } else {
            merge<USDT, USDC>(signer_ref);
        };
    }

    fun merge<X, Y>(signer_ref: &signer) {
        let signer_addr = signer::address_of(signer_ref);
        let x_balance_before_removing_liquidity = coin::balance<X>(signer_addr);
        let y_balance_before_removing_liquidity = coin::balance<Y>(signer_addr);
        let lp_balance = swap_v2::lp_balance<X, Y>(signer_addr);
        // do nothing if signer has no liquidity in the given pair
        if (lp_balance == 0) { return; };
        // remove liquidity from v2 pair
        router_v2::remove_liquidity<X, Y>(signer_ref, lp_balance, 0, 0);
        // calculate amounts to add liquidity
        let x_balance_after_removing_liquidity = coin::balance<X>(signer_addr);
        let y_balance_after_removing_liquidity = coin::balance<Y>(signer_addr);
        // add liquidity to v2.1 pair
        add_liquidity<X, Y>(
            signer_ref,
            x_balance_after_removing_liquidity - x_balance_before_removing_liquidity,
            y_balance_after_removing_liquidity - y_balance_before_removing_liquidity,
            0,
            0
        );
    }
}