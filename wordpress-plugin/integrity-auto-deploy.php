<?php
/**
 * Plugin Name:  Integrity Realty — Auto Deploy
 * Description:  Triggers a Cloudflare Pages rebuild when a property is published, emails admin when a new listing draft is submitted, and exposes ACF fields via REST API.
 * Version:      1.2.0
 * Author:       Integrity Realty
 */

if ( ! defined( 'ABSPATH' ) ) exit;

define( 'INTEGRITY_CF_HOOK', 'https://api.cloudflare.com/client/v4/workers/builds/deploy_hooks/3a6cf029-74fe-4da9-b7b7-282b21667296' );

// ── 1. Auto-deploy to Cloudflare when a property is published ─────────────────
function integrity_trigger_deploy( $post_id, $post, $update ) {
    if ( ! in_array( $post->post_type, array( 'estate_property', 'property' ) ) ) return;
    if ( $post->post_status !== 'publish' ) return;
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) return;
    if ( wp_is_post_revision( $post_id ) ) return;
    if ( get_transient( 'integrity_cf_deploying' ) ) return;
    set_transient( 'integrity_cf_deploying', 1, 60 );

    wp_remote_post( INTEGRITY_CF_HOOK, array(
        'method'   => 'POST',
        'timeout'  => 5,
        'blocking' => false,
    ) );
}
add_action( 'save_post', 'integrity_trigger_deploy', 10, 3 );

// ── 2. Email admin when a new property draft is created via the website ───────
function integrity_notify_new_draft( $post_id, $post, $update ) {
    if ( ! in_array( $post->post_type, array( 'estate_property', 'property' ) ) ) return;
    if ( $post->post_status !== 'draft' ) return;
    if ( $update ) return;
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) return;
    if ( wp_is_post_revision( $post_id ) ) return;

    $admin_email = get_option( 'admin_email' );
    $edit_link   = admin_url( 'post.php?post=' . $post_id . '&action=edit' );
    $subject     = '📋 New Property Listing Submitted: ' . $post->post_title;
    $message     = "A new property listing has been submitted via the website and is waiting for your review.\n\n"
                 . "Title: " . $post->post_title . "\n"
                 . "Review & Publish: " . $edit_link . "\n\n"
                 . "Once you click Publish, the site will automatically rebuild and the listing will go live.";

    wp_mail( $admin_email, $subject, $message );
}
add_action( 'save_post', 'integrity_notify_new_draft', 10, 3 );

// ── 3. Expose all ACF property fields via the REST API ───────────────────────
// Without this, the frontend gets acf:{} even if data is saved in WP Admin.
function integrity_register_property_acf_rest() {
    $acf_fields = array(
        'listing_type', 'property_type', 'price',
        'location_city', 'location_province', 'full_address',
        'bedrooms', 'bathrooms', 'floor_area', 'lot_area',
        'agent_name', 'agent_phone', 'agent_email', 'agent_photo',
        'property_status', 'amenities', 'features', 'property_features',
        'open_house_date', 'virtual_tour_url',
        'photo_2', 'photo_3', 'photo_4', 'photo_5',
        'photo_6', 'photo_7', 'photo_8', 'photo_9', 'photo_10',
        'swimming_pool', 'gym', 'parking', 'balcony',
    );

    register_rest_field( 'property', 'acf', array(
        'get_callback' => function( $post_arr ) use ( $acf_fields ) {
            $result = array();
            foreach ( $acf_fields as $field ) {
                $result[ $field ] = get_post_meta( $post_arr['id'], $field, true );
            }
            return $result;
        },
        'update_callback' => function( $acf_data, $post_obj ) {
            if ( ! is_array( $acf_data ) ) return;
            foreach ( $acf_data as $key => $value ) {
                update_post_meta( $post_obj->ID, sanitize_key( $key ), $value );
            }
        },
        'schema' => array( 'type' => 'object', 'description' => 'ACF property fields' ),
    ) );
}
add_action( 'rest_api_init', 'integrity_register_property_acf_rest' );

// ── 4. Expose user meta (profile_photo, phone) via the REST API ──────────────
// Required for account.astro to read/write profile photo and phone number.
function integrity_register_user_meta_rest() {
    register_meta( 'user', 'profile_photo', array(
        'show_in_rest'  => true,
        'single'        => true,
        'type'          => 'string',
        'auth_callback' => '__return_true',
    ) );
    register_meta( 'user', 'phone', array(
        'show_in_rest'  => true,
        'single'        => true,
        'type'          => 'string',
        'auth_callback' => '__return_true',
    ) );
}
add_action( 'init', 'integrity_register_user_meta_rest' );
