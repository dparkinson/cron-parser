require_relative '../cron_parser'

describe CronParser do
    context 'When parsing a string it extracts' do
        before do
            @parser = CronParser.new('*/5 * 1,15 JAN-DEC MON /bin/bash -c ./do-something')
        end

        it 'the command' do
            expect(@parser.command).to eql('/bin/bash -c ./do-something')
        end

        it 'the minute' do
            expect(@parser.fields[:minute]).to eql('*/5')
        end

        it 'the hour' do
            expect(@parser.fields[:hour]).to eql('*')
        end

        it 'the day of month' do
            expect(@parser.fields[:day_of_month]).to eql('1,15')
        end

        it 'the month' do
            expect(@parser.fields[:month]).to eql('JAN-DEC')
        end

        it 'the day of week' do
            expect(@parser.fields[:day_of_week]).to eql('MON')
        end
    end

    context "When parsing a value" do
        it "it should return the full range of values for a wildcard (e.g. 1..12)" do
            parser = CronParser.new('* * * * * /usr/bin/find')
            expect(parser.month).to eq '1 2 3 4 5 6 7 8 9 10 11 12'
        end

        it "it should return 'Unused' for an optional value" do
            parser = CronParser.new('* * ? * * /usr/bin/find')
            expect(parser.day_of_month).to eq 'Unused'
        end

        context "for a range" do 
            it "it should return a subset of values for a numeric range (e.g. 15-20)" do
                parser = CronParser.new('* 15-20 * * * /usr/bin/find')
                expect(parser.hour).to eq '15 16 17 18 19 20'
            end

            it "it should return a subset of values for a string range (e.g. TUE-FRI)" do
                parser = CronParser.new('* * * * TUE-FRI /usr/bin/find')
                expect(parser.day_of_week).to eq 'TUE WED THU FRI'
            end

            context "that is invalid (e.g. TUE-BOB)" do
                it "it should not populate the field" do
                    parser = CronParser.new('* * * * TUE-BOB /usr/bin/find')
                    expect(parser.day_of_week).to be nil
                end

                it "it should flag the model as invalid" do
                    parser = CronParser.new('* * * * TUE-BOB /usr/bin/find')
                    expect(parser.valid?).to be false
                end

                it "it should populate an error message for the problem" do
                    parser = CronParser.new('* * * * TUE-BOB /usr/bin/find')
                    expect(parser.errors[:day_of_week]).not_to be_empty
                end
            end
        end

        context "for a step interval" do
            it "should return steps matching the interval with a wildcard" do
                parser = CronParser.new('*/15 * * * * /usr/bin/find')
                expect(parser.minute).to eq '0 15 30 45'
            end

            it "should start at a given value and return intervals from that point" do
                parser = CronParser.new('* 5/3 * * * /usr/bin/find')
                expect(parser.hour).to eql '5 8 11 14 17 20 23'
            end

            it "should start at a given string value and return string intervals from that point (e.g. TUE/2)" do
                parser = CronParser.new('* * * * TUE/2 /usr/bin/find')
                expect(parser.day_of_week).to eql 'TUE THU SAT'
            end

            it "should validate that the starting point is within the range" do
                parser = CronParser.new('80/15 * * * * /usr/bin/find')
                expect(parser.errors[:minute]).not_to be_empty
            end
        end

        context "for a list" do
            it "should return only the values in the list" do 
                parser = CronParser.new('* * 1,15 * * /usr/bin/find')
                expect(parser.day_of_month).to eq '1 15'
            end

            it "should allow string values in the list" do 
                parser = CronParser.new('* * * JAN,MAR,MAY * /usr/bin/find')
                expect(parser.month).to eq 'JAN MAR MAY'
            end
        end

        context "for a literal value" do
            it "should return the value" do
                parser = CronParser.new('38 8 * * * /usr/bin/find')
                expect(parser.hour).to eq '8'
            end

            it "should ensure that the value is within a valid range" do
                parser = CronParser.new('90 8 * * * /usr/bin/find')
                expect(parser.errors).not_to be_empty
            end

            it "should allow string based values" do
                parser = CronParser.new('* * * MAY * /usr/bin/find')
                expect(parser.month).to eq 'MAY'
            end
        end

        context "for combined range and literals" do
            it "should allow a range to loop back from the end" do
                parser = CronParser.new("* * * * FRI-MON /usr/bin/find")
                expect(parser.day_of_week).to start_with 'FRI SAT SUN MON'
            end

            it "should append the literal value to the range" do
                parser = CronParser.new("* * * * FRI-MON,WED /usr/bin/find")
                expect(parser.day_of_week).to start_with 'FRI SAT SUN MON WED'
            end
        end
    end

    # context "execution time" do
    #     it "should determine the next time to run with the hours" do
    #         parser = CronParser.new("* 15-20 * * * /usr/bin/find")

    #         date = Date.today

    #         expect(parser.next_run).to eq date.strftime('%Y-%m-%d ') + "15:00"
    #     end
    # end
end
