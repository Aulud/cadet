defmodule Cadet.Auth.Providers.LumiNUSTest do
  @moduledoc """
  This test module uses pre-recorded HTTP responses saved by ExVCR. This allows
  testing without actual external LumiNUS API calls.

  If you need to re-record these responses, set the LumiNUS API key in
  config/test.exs, retrieve a LumiNUS authorisation token, delete the
  pre-recorded responses, and then run

      TOKEN=auth_code_goes_here mix test

  You can retrieve the authorisation token by manually hitting the ADFS and
  LumiNUS endpoints, or just by logging in to LumiNUS in your browser and
  extracting the token from the Authorization header in API requests.

  If you need to re-record the authorise responses, you will have to hit ADFS
  manually to get an authorisation code, and set the appropriate environment
  variables (see the module attributes defined below).

  Note that all the cassettes are marked as custom as they have been manually
  edited to suit the particular test case.
  """

  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias Cadet.Auth.Providers.LumiNUS

  @code System.get_env("CODE") || "CODE"
  @redirect_uri System.get_env("REDIRECT_URI") || "REDIRECT_URI"
  @client_id System.get_env("CLIENT_ID") || "CLIENT_ID"
  @token System.get_env("TOKEN") || "TOKEN"
  @name "TEST LUMINUS USER"

  @config %{
    api_key: "API_KEY",
    module_code: "CS1101S",
    module_term: "2010"
  }

  setup_all do
    HTTPoison.start()
  end

  describe "authorise" do
    test "using a valid code" do
      use_cassette "luminus/authorise#1", custom: true do
        assert {:ok, _} = LumiNUS.authorise(@config, @code, @client_id, @redirect_uri)
      end
    end

    test "using an invalid code" do
      use_cassette "luminus/authorise#2", custom: true do
        assert {:error, :invalid_credentials, "Error from LumiNUS/ADFS: invalid_grant"} =
                 LumiNUS.authorise(@config, @code <> "_invalid", @client_id, @redirect_uri)
      end
    end

    test "using an invalid redirect_uri" do
      use_cassette "luminus/authorise#3", custom: true do
        assert {:error, :invalid_credentials, "Error from LumiNUS/ADFS: invalid_request"} =
                 LumiNUS.authorise(@config, @code, @client_id, @redirect_uri <> "_invalid")
      end
    end

    test "using an invalid client_id" do
      use_cassette "luminus/authorise#4", custom: true do
        assert {:error, :invalid_credentials, "Error from LumiNUS/ADFS: invalid_client"} =
                 LumiNUS.authorise(@config, @code, @client_id <> "_invalid", @redirect_uri)
      end
    end

    test "non-success HTTP code from upstream" do
      use_cassette "luminus/authorise#5", custom: true do
        assert {:error, :upstream, "Status code 500 from LumiNUS: "} =
                 LumiNUS.authorise(@config, @code, @client_id, @redirect_uri)
      end
    end

    test "no username in token from upstream" do
      use_cassette "luminus/authorise#6", custom: true do
        assert {:error, :invalid_credentials, "Could not retrieve username from token"} =
                 LumiNUS.authorise(@config, @code, @client_id, @redirect_uri)
      end
    end

    test "expired token from upstream" do
      use_cassette "luminus/authorise#7", custom: true do
        assert {:error, :invalid_credentials, "Failed to verify token claims (token expired?)"} =
                 LumiNUS.authorise(@config, @code, @client_id, @redirect_uri)
      end
    end
  end

  describe "Fetch details" do
    test "Using a valid token" do
      use_cassette "luminus/get_name#1", custom: true do
        assert {:ok, @name} = LumiNUS.get_name(@config, @token)
      end
    end

    test "Using an invalid token" do
      use_cassette "luminus/get_name#2", custom: true do
        assert {:error, :upstream, _} = LumiNUS.get_name(@config, @token <> "Z")
      end
    end
  end

  describe "Fetch a role" do
    test "Using a valid token" do
      use_cassette "luminus/get_role#1", custom: true do
        assert {:ok, role} = LumiNUS.get_role(@config, @token)
        assert role in [:student, :staff, :admin]
      end
    end

    test "Using an invalid token" do
      use_cassette "luminus/get_role#2", custom: true do
        assert {:error, :upstream, _} = LumiNUS.get_role(@config, @token <> "Z")
      end
    end
  end

  describe "Map access rights to correct role" do
    test "User does not read CS1101S" do
      use_cassette "luminus/get_role#3", custom: true do
        assert {:error, :invalid_credentials, "User is not part of module"} =
                 LumiNUS.get_role(@config, @token)
      end
    end

    test "User no longer reads CS1101S" do
      use_cassette "luminus/get_role#4", custom: true do
        assert {:error, :invalid_credentials, "User is not part of module"} =
                 LumiNUS.get_role(@config, @token)
      end
    end

    test "User is staff of CS1101S from old semester" do
      use_cassette "luminus/get_role#10", custom: true do
        assert {:error, :invalid_credentials, "User is not part of module"} =
                 LumiNUS.get_role(@config, @token)
      end
    end

    test "Student role maps to :student" do
      use_cassette "luminus/get_role#5", custom: true do
        assert {:ok, :student} = LumiNUS.get_role(@config, @token)
      end
    end

    test "Read Manager role maps to :staff" do
      use_cassette "luminus/get_role#6", custom: true do
        assert {:ok, :staff} = LumiNUS.get_role(@config, @token)
      end
    end

    test "Manager role maps to :staff" do
      use_cassette "luminus/get_role#7", custom: true do
        assert {:ok, :staff} = LumiNUS.get_role(@config, @token)
      end
    end

    test "Owner/Co-owner role maps to :admin" do
      use_cassette "luminus/get_role#8", custom: true do
        assert {:ok, :admin} = LumiNUS.get_role(@config, @token)
      end
    end

    test "Unknown access role" do
      use_cassette "luminus/get_role#9", custom: true do
        assert {:error, :other, "Unexpected access combination"} =
                 LumiNUS.get_role(@config, @token)
      end
    end
  end
end
